{
  config,
  inputs',
  pkgs,
  ...
}:
let
  inherit (config.sops) secrets;
  mailHostname = "mail.pointjig.de";
in
{
  sops.secrets = {
    sms-technical-passwd = { };
    sms-shawn-passwd = { };
    mimir-env = {
      owner = "mimir";
      group = "mimir";
    };
    stfc-env = {
      owner = "stfcbot";
      group = "stfcbot";
    };
    stalwart-env = { };
  };

  networking.firewall = {
    allowedUDPPorts = [ 443 ];
    allowedTCPPorts = [
      80
      443
      # Mail ports for stalwart
      25
      587
      993
      4190
    ];
  };

  systemd = {
    network = {
      enable = true;
      networks = {
        "20-wired" = {
          matchConfig.Name = "enp6s18";
          networkConfig = {
            Address = [
              "134.255.226.114/28"
              "2a05:bec0:1:16::114/64"
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
      wait-online.anyInterface = true;
    };
    services.stalwart-mail.serviceConfig = {
      User = "stalwart-mail";
      EnvironmentFile = [ secrets.stalwart-env.path ];
    };
  };

  # So that we can read acme certificate from nginx
  users.users.stalwart-mail.extraGroups = [ "nginx" ];

  services = {
    fstrim.enable = true;
    postgresql = {
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
      ensureDatabases = [ "stalwart-mail" ];
      ensureUsers = [
        {
          name = "stalwart-mail";
          ensureDBOwnership = true;
        }
      ];
    };
    nginx = {
      package = pkgs.nginxQuic;
      virtualHosts."pointjig.de" = {
        enableACME = true;
        forceSSL = true;
        globalRedirect = mailHostname;
      };
      virtualHosts."${mailHostname}" = {
        serverName = "${mailHostname}";
        forceSSL = true;
        enableACME = true;
        http3 = true;
        kTLS = true;
        locations = {
          "/" = {
            proxyPass = "http://localhost:8080";
            recommendedProxySettings = true;
          };
        };
      };
    };
    stne-mimir = {
      enable = true;
      domain = "mimir.pointjig.de";
      clientPackage = inputs'.mimir-client.packages.default;
      package = inputs'.mimir.packages.default;
      envFile = secrets.mimir-env.path;
      unixSocket = "/run/mimir-backend/mimir-backend.sock";
    };
    stfc-bot = {
      enable = true;
      package = inputs'.stfc-bot.packages.default;
      envFile = secrets.stfc-env.path;
    };
    stalwart-mail = {
      enable = true;
      settings = {
        store.db = {
          type = "postgresql";
          host = "localhost";
          password = "%{env:POSTGRESQL_PASSWORD}%";
          port = 5432;
          database = "stalwart-mail";
        };
        storage.blob = "db";

        authentication.fallback-admin = {
          user = "admin";
          secret = "%{env:FALLBACK_ADMIN_PASSWORD}%";
        };
        lookup.default.hostname = mailHostname;
        certificate.default = {
          private-key = "%{file:/var/lib/acme/${mailHostname}/key.pem}%";
          cert = "%{file:/var/lib/acme/${mailHostname}/cert.pem}%";
          default = true;
        };
        spam-filter.resource = "file://${pkgs.stalwart-mail}/etc/stalwart/spamfilter.toml";
        webadmin = {
          path = "/var/cache/stalwart-mail";
          resource = "file://${pkgs.stalwart-mail.webadmin}/webadmin.zip";
        };

        server = {
          http.use-x-forwarded = true;
          tls.enable = true;
          listener = {
            "smtp" = {
              bind = [ "[::]:25" ];
              protocol = "smtp";
            };
            "submission" = {
              bind = [ "[::]:587" ];
              protocol = "smtp";
            };
            "imaptls" = {
              bind = [ "[::]:993" ];
              protocol = "imap";
              tls.implicit = true;
            };
            "sieve" = {
              bind = [ "[::]:4190" ];
              protocol = "managesieve";
            };
            "http" = {
              bind = [ "127.0.0.1:8080" ];
              protocol = "http";
            };
          };
        };
      };
    };
  };

  security = {
    auditd.enable = false;
    audit.enable = false;
  };

  shawn8901 = {
    postgresql.enable = true;
    server.enable = true;
  };
}
