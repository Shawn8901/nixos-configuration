{
  cfg,
  self,
  ...
}:
{
  den.aspects.shelter.provides.to-users = {
    includes = [
      cfg.monitoree
      cfg.server
      cfg.zfs
      cfg.zrepl
    ];

    nixos =
      {
        config,
        modulesPath,
        lib,
        ...
      }:
      {

        imports = [
          "${modulesPath}/profiles/headless.nix"
          # raise error with disko about missing /proc/mounts
          #"${modulesPath}/profiles/perlless.nix"
        ];
        # We dont build fully perlless yet
        system.forbiddenDependenciesRegexes = lib.mkForce [ ];

        sops = {
          defaultSopsFile = ./secrets.yaml;
          secrets.zrepl = { };
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
                ca = self.outPath + "/files/certs/zrepl/tank.crt";
                cert = self.outPath + "/files/certs/zrepl/shelter.crt";
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
        };
      };
  };
}
