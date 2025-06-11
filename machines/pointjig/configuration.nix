{
  config,
  inputs',
  pkgs,
  lib,
  ...
}:
let
  inherit (builtins) concatStringsSep;
  inherit (config.sops) secrets;
  mailHostname = "mail.pointjig.de";
  vaultwardenName = "vault.pointjig.de";
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
    vaultwarden = { };
    maxmind = { };
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
    services = {
      stalwart-mail.serviceConfig = {
        User = "stalwart-mail";
        EnvironmentFile = [ secrets.stalwart-env.path ];
      };
      vaultwarden = {
        after = [ "postgresql.service" ];
        requires = [ "postgresql.service" ];
        serviceConfig = {
          StateDirectory = lib.mkForce "vaultwarden"; # modules defaults to bitwarden_rs
        };
      };
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
      ensureDatabases = [
        "stalwart-mail"
        "vaultwarden"
      ];
      ensureUsers = [
        {
          name = "stalwart-mail";
          ensureDBOwnership = true;
        }
        {
          name = "vaultwarden";
          ensureDBOwnership = true;
        }
      ];
    };
    geoipupdate = {
      enable = true;
      settings = {
        AccountID = 1181822;
        EditionIDs = [ "GeoLite2-Country" ];
        LicenseKey = secrets.maxmind.path;
      };
    };
    nginx =
      let
        forbidNotAllowedCountries = ''
          if ($allowed_country = 0) {
            return 403;
          }
        '';
      in
      {
        package = pkgs.nginxQuic;
        additionalModules = with pkgs.nginxModules; [
          geoip2
        ];
        virtualHosts."pointjig.de" = {
          enableACME = true;
          forceSSL = true;
          globalRedirect = mailHostname;
        };
        recommendedBrotliSettings = true;
        recommendedGzipSettings = true;
        recommendedOptimisation = true;
        recommendedTlsSettings = true;
        recommendedZstdSettings = true;
        enableReload = true;
        clientMaxBodySize = "40M";
        mapHashMaxSize = 4096;
        appendHttpConfig =
          let
            allowedCountries = [ "DE" ];
            geoDbCountryPath = "${config.services.geoipupdate.settings.DatabaseDirectory}/GeoLite2-Country.mmdb";
          in
          ''
            geoip2 ${geoDbCountryPath} {
              auto_reload 5m;
              $geoip2_country_code country iso_code;
            }
            map $geoip2_country_code $allowed_country {
              default 0;
              ${concatStringsSep "\n  " (map (c: "${c} 1;") allowedCountries)}
            }
          '';

        virtualHosts = {
          "${mailHostname}" = {
            serverName = "${mailHostname}";
            forceSSL = true;
            enableACME = true;
            http3 = true;
            kTLS = true;
            locations = {
              "/" = {
                proxyPass = "http://localhost:8080";
                recommendedProxySettings = true;
                extraConfig = ''
                  ${forbidNotAllowedCountries}
                '';
              };
            };
          };
          "${vaultwardenName}" = {
            serverName = vaultwardenName;
            forceSSL = true;
            enableACME = true;
            http3 = true;
            kTLS = true;
            locations."/" = {
              proxyPass = "http://localhost:${toString config.services.vaultwarden.config.ROCKET_PORT}";
              extraConfig = ''
                ${forbidNotAllowedCountries}
              '';
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
    vaultwarden = {
      enable = true;
      dbBackend = "postgresql";
      environmentFile = secrets.vaultwarden.path;
      config = {
        DATABASE_URL = "postgresql:///vaultwarden?host=/run/postgresql";
        DOMAIN = "https://${vaultwardenName}";
        DATA_FOLDER = "/var/lib/vaultwarden";
        ENABLE_WEBSOCKET = true;
        LOG_LEVEL = "warn";
        PASSWORD_ITERATIONS = 600000;
        ROCKET_ADDRESS = "127.0.0.1";
        ROCKET_PORT = 8222;
        SIGNUPS_ALLOWED = false;
        TRASH_AUTO_DELETE_DAYS = 30;
        SMTP_HOST = "mail.pointjig.de";
        SMTP_FROM = "noreply@pointjig.de";
        SMTP_FROM_NAME = "Vaultwarden";
        SMTP_USERNAME = "postman";
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
