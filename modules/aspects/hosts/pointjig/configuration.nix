{ cfg, inputs, ... }:
{
  den.aspects.pointjig.provides.to-users = {
    includes = [
      cfg.monitoree
      cfg.server
      cfg.postgresql
    ];
    nixos =
      {
        config,
        pkgs,
        lib,
        ...
      }:
      let
        inherit (builtins) concatStringsSep;
        inherit (config.sops) secrets;
        vaultwardenName = "vault.pointjig.de";
        mailHostname = "mail.pointjig.de";
      in
      {

        imports = [ inputs.snm.nixosModules.default ];

        sops = {
          defaultSopsFile = ./secrets.yaml;
          secrets = {
            vaultwarden = { };
            maxmind = { };
            snm-shawn = { };
            snm-dorman = { };
          };
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
          services.vaultwarden = {
            serviceConfig.StateDirectory = lib.mkForce "vaultwarden";
            after = [ "postgresql.target" ];
            requires = [ "postgresql.target" ];
          };
        };

        services = {
          fstrim.enable = true;
          postgresql = {
            package = pkgs.postgresql_16;
            dataDir = "/var/lib/postgresql/${config.services.postgresql.package.psqlSchema}";
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
              "stalwart"
              "vaultwarden"
            ];
            ensureUsers = [
              {
                name = "stalwart";
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
              allowedCountries = [ "DE" ];
              geoDbCountryPath = "${config.services.geoipupdate.settings.DatabaseDirectory}/GeoLite2-Country.mmdb";
            in
            {
              package = pkgs.nginx;
              additionalModules = with pkgs.nginxModules; [ geoip2 ];
              virtualHosts."pointjig.de" = {
                enableACME = true;
                forceSSL = true;
                globalRedirect = vaultwardenName;
              };
              recommendedGzipSettings = true;
              recommendedOptimisation = true;
              recommendedTlsSettings = true;
              enableReload = true;
              clientMaxBodySize = "40M";
              mapHashMaxSize = 4096;
              appendHttpConfig = ''
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
                  locations."/" = {
                    extraConfig = ''
                      return 200;
                    '';
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
              ICON_SERVICE = "internal";
            };
          };
        };

        mailserver = {
          enable = true;
          stateVersion = 4;
          fqdn = "mail.pointjig.de";
          domains = [ "pointjig.de" ];
          x509.useACMEHost = config.mailserver.fqdn;
          accounts = {
            "shawn@pointjig.de" = {
              hashedPasswordFile = secrets.snm-shawn.path;
              aliases = [
                "aktienfinder@pointjig.de"
                "alphavps@pointjig.de"
                "aquatuning@pointjig.de"
                "atlas@pointjig.de"
                "caseking@pointjig.de"
                "check24@pointjig.de"
                "circular@pointjig.de"
                "codeberg@pointjig.de"
                "dropbox@pointjig.de"
                "eatventure@pointjig.de"
                "epic@pointjig.de"
                "estateguru@pointjig.de"
                "flexispot@pointjig.de"
                "fritz@pointjig.de"
                "geizhals@pointjig.de"
                "intex@pointjig.de"
                "kinguin@pointjig.de"
                "lotto@pointjig.de"
                "megaprimus@pointjig.de"
                "milesandmore@pointjig.de"
                "mindfactory@pointjig.de"
                "nb@pointjig.de"
                "osaio@pointjig.de"
                "parqet@pointjig.de"
                "planetside@pointjig.de"
                "pool@pointjig.de"
                "reddit@pointjig.de"
                "smite@pointjig.de"
                "spocks@pointjig.de"
                "spotify@pointjig.de"
                "steam@pointjig.de"
                "stfc@pointjig.de"
                "stne@pointjig.de"
                "sto@pointjig.de"
                "supremegamers@pointjig.de"
                "unity@pointjig.de"
                "zsa@pointjig.de"
              ];
            };
            "dorman@pointjig.de" = {
              hashedPasswordFile = secrets.snm-dorman.path;
              aliases = [
                "ninjatrader@pointjig.de"
              ];
            };
          };
        };
      };
  };
}
