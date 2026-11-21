{
  config,
  modulesPath,
  sources,
  lib,
  ...
}:
{

  imports = [
    "${modulesPath}/profiles/perlless.nix"
    "${modulesPath}/profiles/headless.nix"
    "${sources.disko}/module.nix"
    ./disko-config.nix
    ./hardware.nix
  ];
  sops = {
    defaultSopsFile = ./secrets.yaml;
    secrets.zrepl = { };
  };
  # used by grub
  system.forbiddenDependenciesRegexes = lib.mkForce [ ];

  includes = {
    managed-users.enable = true;
    monitoree.enable = true;
    server.enable = true;
    zfs.enable = true;
    zrepl.enable = true;
  };

  systemd = {
    network = {
      enable = true;
      networks = {
        "20-wired" = {
          matchConfig.Name = "ens3";
          networkConfig = {
            Address = [
              "78.128.127.235/25"
              "2a01:8740:1:e4::2cd3/64"
            ];
            DNS = "8.8.8.8";
            Gateway = "78.128.127.129";
          };
          routes = [
            {
              Gateway = "2a01:8740:0001:0000:0000:0000:0000:0001";
              GatewayOnLink = "yes";
            }
          ];
        };
      };
      wait-online.anyInterface = true;
    };
  };

  services = {
    zfs.autoScrub.pools = [ "zbackup" ];
    zrepl.settings.jobs = [
      {
        name = "ztank_sink";
        type = "sink";
        root_fs = "zbackup/replica";
        serve = {
          type = "tls";
          listen = ":8888";
          ca = ../tank/zrepl.crt;
          cert = ./zrepl.crt;
          key = config.sops.secrets.zrepl.path;
          client_cns = [ "tank" ];
        };
        recv = {
          placeholder = {
            encryption = "inherit";
          };
        };
      }
    ];
    # vserver has no real disk available
    smartd.enable = false;
  };
}
