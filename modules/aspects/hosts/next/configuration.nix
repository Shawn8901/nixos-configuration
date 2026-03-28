{ cfg, ... }:
{
  den.aspects.next = {
    includes = [
      cfg.monitoree
      cfg.server
      cfg.postgresql
      cfg.nextcloud
    ];

    nixos =
      { config, pkgs, ... }:
      {
        sops = {
          defaultSopsFile = ./secrets.yaml;
          secrets = {
            root = { };
            nextcloud-admin = {
              owner = "nextcloud";
              group = "nextcloud";
            };
            prometheus-nextcloud = {
              owner = config.services.prometheus.exporters.nextcloud.user;
              inherit (config.services.prometheus.exporters.nextcloud) group;
            };
          };
        };

        systemd.network = {
          enable = true;
          networks."20-wired" = {
            matchConfig.Name = "enp6s18";
            networkConfig = {
              Address = [
                "134.255.226.115/28"
                "2a05:bec0:1:16::115/64"
              ];
              DNS = "8.8.8.8";
              Gateway = "134.255.226.113";
            };
            routes = [
              {
                Gateway = "2a05:bec0:1:16::1";
                GatewayOnLink = "yes";
              }
            ];
          };
        };

        services = {
          fstrim.enable = true;
          nginx.package = pkgs.nginx;
          postgresql.package = pkgs.postgresql_16;
          nextcloud = {
            hostName = "next.clansap.org";
            home = "/var/lib/nextcloud";
            package = pkgs.nextcloud32;
            imaginary.enable = true;
            recommendedDefaults = true;
          };
        };
        security.acme.defaults.email = "info@clansap.org";
        users.mutableUsers = false;
        users.users.root = {
          hashedPasswordFile = config.sops.secrets.root.path;
          openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMguHbKev03NMawY9MX6MEhRhd6+h2a/aPIOorgfB5oM shawn"
          ];
        };
      };
  };
}
