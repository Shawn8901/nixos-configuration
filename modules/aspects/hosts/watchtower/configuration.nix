{ cfg, ... }:
{
  den.aspects.watchtower.provides.to-users = {
    includes = [
      cfg.monitoree
      cfg.server
      cfg.postgresql
      cfg.remote-builder
    ];

    nixos =
      {
        config,
        pkgs,
        modulesPath,
        ...
      }:
      {

        imports = [
          "${modulesPath}/profiles/headless.nix"
          "${modulesPath}/profiles/perlless.nix"
        ];
        sops.defaultSopsFile = ./secrets.yaml;

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
          openssh.hostKeys = [
            {
              path = "/static/etc/ssh/ssh_host_ed25519_key";
              type = "ed25519";
            }
            {
              path = "/static/etc/ssh/ssh_host_rsa_key";
              type = "rsa";
              bits = 4096;
            }
          ];
          nginx.package = pkgs.nginx;
          vmagent = {
            package = pkgs.victoriametrics;
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
          postgresql.package = pkgs.postgresql_16;
        };

        users.users.root.openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMguHbKev03NMawY9MX6MEhRhd6+h2a/aPIOorgfB5oM"
        ];
      };
  };
}
