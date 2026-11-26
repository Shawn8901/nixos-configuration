{
  config,
  pkgs,
  modulesPath,
  sources,
  ...
}:
{

  imports = [
    "${modulesPath}/profiles/headless.nix"
    "${modulesPath}/profiles/perlless.nix"
    ./hardware.nix
    "${sources.disko}/module.nix"
    ./disko-config.nix
    ./attic-server.nix
    ./grafana.nix
    ./hydra.nix
    ./victorialogs.nix
    ./victoriametrics.nix
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

  includes = {
    managed-users.enable = true;
    monitoree.enable = true;
    postgresql.enable = true;
    server.enable = true;
  };

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
    nginx = {
      enable = true;
      package = pkgs.nginx;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedTlsSettings = true;
      recommendedProxySettings = true;
    };
    vmagent = {
      package = pkgs.victoriametrics;
      remoteWrite.url = "http://${config.services.victoriametrics.listenAddress}/api/v1/write";
    };
    postgresql.package = pkgs.postgresql_16;
    # vserver has no real disk available
    smartd.enable = false;
  };
}
