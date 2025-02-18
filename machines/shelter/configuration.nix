{
  config,
  flakeConfig,
  inputs',
  modulesPath,
  lib,
  ...
}:
let
  uPkgs = inputs'.nixpkgs.legacyPackages;

  inherit (config.sops) secrets;
in
{

  imports = [
    "${modulesPath}/profiles/headless.nix"
    "${modulesPath}/profiles/perlless.nix"
  ];
  # We dont build fully perlless yet
  system.forbiddenDependenciesRegexes = lib.mkForce [ ];

  sops.secrets = {
    zrepl = { };
  };

  networking.firewall = {
    allowedTCPPorts = flakeConfig.shawn8901.zrepl.servePorts config.services.zrepl;
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
    zfs.autoScrub = {
      enable = true;
      pools = [ "zbackup" ];
    };
    zrepl = {
      enable = true;
      package = uPkgs.zrepl;
      settings = {
        global = {
          monitoring = [
            {
              type = "prometheus";
              listen = ":9811";
              listen_freebind = true;
            }
          ];
        };
        jobs = [
          {
            name = "ztank_sink";
            type = "sink";
            root_fs = "zbackup/replica";
            serve = {
              type = "tls";
              listen = ":8888";
              ca = ../../files/public_certs/zrepl/tank.crt;
              cert = ../../files/public_certs/zrepl/shelter.crt;
              key = secrets.zrepl.path;
              client_cns = [ "tank" ];
            };
            recv = {
              placeholder = {
                encryption = "inherit";
              };
            };
          }
        ];
      };
    };
  };
  security = {
    auditd.enable = false;
    audit.enable = false;
  };

  shawn8901.server.enable = true;
}
