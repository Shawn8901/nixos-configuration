{
  inputs',
  config,
  pkgs,
  modulesPath,
  ...
}:
let
  inherit (config.sops) secrets;

  vmPackage = pkgs.victoriametrics.override {
    withBackupTools = false;
    withVmAlert = false;
    withVmctl = false;
    withVmAgent = true;
  };
in
{

  imports = [
    "${modulesPath}/profiles/headless.nix"
    ./disko-config.nix
  ];

  sops.secrets = {
    root = {
      neededForUsers = true;
    };
    attic-env = { };
    grafana-env = {
      owner = "grafana";
      group = "grafana";
    };
    victoriametrics = { };
  };

  networking = {
    nameservers = [
      "208.67.222.222"
      "208.67.220.220"
    ];
    domain = "";
    useDHCP = true;
  };
  systemd.network.wait-online.anyInterface = true;

  services = {
    nginx.package = pkgs.nginxQuic;
    vmagent = {
      package = vmPackage;
      remoteWrite.url = "http://${config.services.victoriametrics.listenAddress}/api/v1/write";
      prometheusConfig.scrape_configs = [
        {
          job_name = "blackbox_exporter";
          static_configs = [
            {
              targets = [ "localhost:${toString config.services.prometheus.exporters.blackbox.port}" ];
            }
          ];
        }
        {
          job_name = "blackbox";
          metrics_path = "/probe";
          params.module = [ "http_2xx" ];
          static_configs = [
            {
              targets = [
                "https://sapsrv01.clansap.org:8006"
                "https://sapsrv02.clansap.org:8006"
              ];
            }
          ];
          relabel_configs = [
            {
              source_labels = [ "__address__" ];
              target_label = "__param_target";
            }
            {
              source_labels = [ "__param_target" ];
              target_label = "target";
            }
            {
              replacement = "127.0.0.1:${toString config.services.prometheus.exporters.blackbox.port}";
              target_label = "__address__";
            }
          ];
        }
      ];
    };
    prometheus = {
      enable = true;
      exporters.blackbox = {
        enable = true;
        listenAddress = "localhost";
        configFile = (pkgs.formats.yaml { }).generate "config.yml" {
          modules = {
            http_2xx = {
              prober = "http";
              http = {
                preferred_ip_protocol = "ip4";
              };
            };
          };
        };
      };
    };
  };

  users.mutableUsers = false;
  users.users.root = {
    hashedPasswordFile = secrets.root.path;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMguHbKev03NMawY9MX6MEhRhd6+h2a/aPIOorgfB5oM"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGsHm9iUQIJVi/l1FTCIFwGxYhCOv23rkux6pMStL49N"
    ];
  };

  shawn8901 = {
    postgresql = {
      enable = true;
      package = pkgs.postgresql_16;
    };
    attic = {
      enable = true;
      hostName = "cache.pointjig.de";
      package = inputs'.nixpkgs.legacyPackages.attic-server;
      environmentFile = secrets.attic-env.path;
    };
    victoriametrics = {
      enable = true;
      hostname = "vm.pointjig.de";
      package = vmPackage;
      username = "vm";
      credentialsFile = secrets.victoriametrics.path;
    };
    grafana = {
      enable = true;
      hostname = "grafana.pointjig.de";
      credentialsFile = secrets.grafana-env.path;
      declarativePlugins = with pkgs.grafanaPlugins; [
        victoriametrics-logs-datasource
        victoriametrics-metrics-datasource
      ];
      datasources = [
        {
          name = "VictoriaMetrics Metrics";
          type = "victoriametrics-metrics-datasource";
          url = "http://${config.services.victoriametrics.listenAddress}";
          basicAuth = true;
          basicAuthUser = "vm";
          isDefault = true;
          secureJsonData.basicAuthPassword = "$DATASOURCE_PASSWORD";
        }
      ];
      deleteDatasources = [
        {
          name = "VictoriaMetrics";
          orgId = 1;
        }
      ];
    };
    server.enable = true;
  };
}
