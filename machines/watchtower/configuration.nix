{
  self',
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
    withVictoriaLogs = false;
    withVmctl = false;
    withVmAgent = true;
  };
in
{

  imports = [ "${modulesPath}/profiles/headless.nix" ];

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
      declarativePlugins = [ self'.packages.victoriametrics-metrics-datasource ];
      settings.plugins.allow_loading_unsigned_plugins = "victoriametrics-metrics-datasource";
      datasources = [
        {
          name = "VictoriaMetrics";
          type = "victoriametrics-metrics-datasource";
          url = "http://${config.services.victoriametrics.listenAddress}";
          basicAuth = true;
          basicAuthUser = "vm";
          isDefault = true;
          secureJsonData.basicAuthPassword = "$DATASOURCE_PASSWORD";
        }
      ];
    };
    server.enable = true;
  };
}
