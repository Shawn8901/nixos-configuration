{ lib, config, ... }:
let
  inherit (config.sops) secrets;
  inherit (builtins) concatStringsSep;
  vaultwardenName = "vault.pointjig.de";
in
{
  sops = {
    defaultSopsFile = ./secrets.yaml;
    secrets = {
      vaultwarden = { };
      maxmind = { };
    };
  };

  systemd.services.vaultwarden = {
    serviceConfig.StateDirectory = lib.mkForce "vaultwarden";
    after = [ "postgresql.target" ];
    requires = [ "postgresql.target" ];
  };

  services = {
    postgresql = {
      enable = true;
      ensureDatabases = [
        "vaultwarden"
      ];
      ensureUsers = [
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
        virtualHosts."${vaultwardenName}" = {
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
}
