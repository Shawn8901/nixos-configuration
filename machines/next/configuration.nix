{
  config,
  pkgs,
  ...
}: let
  inherit (config.sops) secrets;
in {
  sops.secrets = {
    root = {};
    nextcloud-admin = {
      owner = "nextcloud";
      group = "nextcloud";
    };
  };

  systemd = {
    network = {
      enable = true;
      networks = {
        "20-wired" = {
          matchConfig.Name = "enp6s18";
          networkConfig.Address = ["134.255.226.115/28" "2a05:bec0:1:16::115/64"];
          networkConfig.DNS = "8.8.8.8";
          networkConfig.Gateway = "134.255.226.113";
          routes = [
            {
              routeConfig = {
                Gateway = "2a05:bec0:1:16::1";
                GatewayOnLink = "yes";
              };
            }
          ];
        };
      };
    };
  };

  services = {
    fstrim.enable = true;
    nginx.package = pkgs.nginxQuic;
  };
  security = {
    acme.defaults.email = "info@clansap.org";
    auditd.enable = false;
    audit.enable = false;
  };

  users.mutableUsers = false;
  users.users.root = {
    passwordFile = secrets.root.path;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMguHbKev03NMawY9MX6MEhRhd6+h2a/aPIOorgfB5oM shawn"
    ];
  };

  shawn8901 = {
    nextcloud = {
      enable = true;
      hostName = "next.clansap.org";
      adminPasswordFile = secrets.nextcloud-admin.path;
      home = "/var/lib/nextcloud";
      package = pkgs.nextcloud25;
      prometheus.passwordFile = secrets.prometheus-nextcloud.path;
    };
    postgresql = {
      enable = true;
      package = pkgs.postgresql_15;
    };
  };
}
