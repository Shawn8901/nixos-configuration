{
  config,
  pkgs,
  sources,
  modulesPath,
  lib,
  ...
}:
{
  imports = [
    "${modulesPath}/profiles/perlless.nix"
    "${sources.snm}"
    ./hardware.nix
    "${sources.preservation}/module.nix"
    ./preservation.nix
    "${sources.disko}/module.nix"
    ./disko-config.nix
    ./valheim.nix
    ./vaultwarden.nix
  ];
  # steamcmd pulls perl
  system.forbiddenDependenciesRegexes = lib.mkForce [ ];

  sops = {
    defaultSopsFile = ./secrets.yaml;
    secrets.zrepl = { };
  };

  includes = {
    managed-users.enable = true;
    mailserver.enable = true;
    monitoree.enable = true;
    postgresql.enable = true;
    server.enable = true;
    zfs.enable = true;
    zrepl.enable = true;
  };

  networking.firewall = {
    allowedUDPPorts = [ 443 ];
    allowedTCPPorts = [
      80
      443
    ];
  };

  systemd = {
    network = {
      enable = true;
      networks = {
        "20-wired" = {
          matchConfig.Name = "ens3";
          networkConfig = {
            Address = [
              "152.53.44.132/22"
              "2a0a:4cc0:0:23b0::/64"
            ];
            DNS = "8.8.8.8";
            Gateway = "152.53.44.1";
          };
          routes = [
            {
              Gateway = "fe80::1";
              GatewayOnLink = "yes";
            }
          ];
        };
      };
      wait-online.anyInterface = true;
    };
  };

  services = {
    fstrim.enable = true;
    postgresql = {
      package = pkgs.postgresql_16;
      dataDir = "/persist/var/lib/postgresql/${config.services.postgresql.package.psqlSchema}";
      settings = {
        max_connections = 200;
        shared_buffers = "1GB";
        effective_cache_size = "3GB";
        maintenance_work_mem = "256MB";
        checkpoint_completion_target = 0.9;
        wal_buffers = "16MB";
        default_statistics_target = 100;
        random_page_cost = 4;
        effective_io_concurrency = 2;
        work_mem = "1310kB";
        huge_pages = "off";
        min_wal_size = "1GB";
        max_wal_size = "4GB";
        track_activities = true;
        track_counts = true;
        track_io_timing = true;
      };
    };
    nginx = {
      package = pkgs.nginx;
      additionalModules = with pkgs.nginxModules; [ geoip2 ];
      virtualHosts."pointjig.de" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          extraConfig = ''
            return 204;
          '';
        };
      };
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedTlsSettings = true;
      enableReload = true;
      clientMaxBodySize = "40M";
      mapHashMaxSize = 4096;
    };
    # vserver has no real disk available
    smartd.enable = false;
    zfs.autoScrub.pools = [ "rpool" ];
    zrepl.settings.jobs = [
      {
        name = "pointjig_safe";
        type = "source";
        filesystems = {
          "rpool/safe<" = true;
        };
        snapshotting = {
          type = "periodic";
          interval = "1h";
          prefix = "zrepl_";
        };
        send = {
          encrypted = false;
          compressed = true;
        };
        serve = {
          type = "tls";
          listen = ":8888";
          ca = ../../hosts/tank/zrepl.crt;
          cert = ./zrepl.crt;
          key = config.sops.secrets.zrepl.path;
          client_cns = [ "tank" ];
        };
      }
    ];
  };
  mailserver = {
    fqdn = "mail.pointjig.de";
    accounts = {
      "shawn@pointjig.de".catchAll = [ config.includes.mailserver.domain ];
    };
  };
}
