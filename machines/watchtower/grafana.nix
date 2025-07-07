{ lib, config, ... }:
let
  inherit (lib)
    types
    mkEnableOption
    mkOption
    mkDefault
    mkIf
    ;

  cfg = config.shawn8901.grafana;
in
{
  options = {
    shawn8901.grafana = {
      enable = mkEnableOption "Enables a preconfigured grafana instance";
      hostname = mkOption {
        type = types.str;
        description = "full qualified hostname of the grafana instance";
      };
      credentialsFile = mkOption { type = types.path; };
      datasources = mkOption { type = types.listOf types.raw; };
      deleteDatasources = mkOption {
        type = types.listOf types.raw;
        default = [ ];
      };
      declarativePlugins = mkOption {
        type = with types; nullOr (listOf path);
        default = null;
      };
      settings = mkOption { type = types.attrs; };
    };
  };
  config = mkIf cfg.enable {
    systemd.services.grafana.serviceConfig.EnvironmentFile = [ cfg.credentialsFile ];
    networking.firewall = {
      allowedUDPPorts = [ 443 ];
      allowedTCPPorts = [
        80
        443
      ];
    };
    services = {
      nginx = {
        enable = mkDefault true;
        recommendedBrotliSettings = true;
        recommendedGzipSettings = true;
        recommendedOptimisation = true;
        recommendedTlsSettings = true;
        recommendedZstdSettings = true;
        recommendedProxySettings = true;
        virtualHosts."${cfg.hostname}" = {
          enableACME = true;
          forceSSL = true;
          http3 = true;
          kTLS = true;
          locations."/" = {
            proxyPass = "http://127.0.0.1:${toString config.services.grafana.settings.server.http_port}";
            proxyWebsockets = true;
            recommendedProxySettings = true;
          };
        };
      };
      postgresql = {
        ensureDatabases = [ "${config.services.grafana.settings.database.name}" ];
        ensureUsers = [
          {
            name = "${config.services.grafana.settings.database.user}";
            ensureDBOwnership = true;
          }
        ];
      };
      grafana = {
        enable = true;
        inherit (cfg) declarativePlugins;
        settings = {
          server = {
            domain = cfg.hostname;
            http_addr = "127.0.0.1";
            http_port = 3001;
            root_url = "https://${cfg.hostname}/";
            enable_gzip = true;
          };
          database = {
            type = "postgres";
            host = "/run/postgresql";
            user = "grafana";
            password = "$__env{DB_PASSWORD}";
          };
          security = {
            admin_password = "$__env{ADMIN_PASSWORD}";
            secret_key = "$__env{SECRET_KEY}";
            cookie_secure = true;
            content_security_policy = true;
          };
          smtp = {
            enabled = true;
            host = "mail.pointjig.de:465";
            user = "noreply@pointjig.de";
            password = "$__env{SMTP_PASSWORD}";
            from_address = "noreply@pointjig.de";
          };
          analytics = {
            check_for_updates = false;
            reporting_enabled = false;
          };
        };
        provision = {
          enable = true;

          alerting = {
            contactPoints.settings = {
              apiVersion = 1;
              contactPoints = [
                {
                  orgId = 1;
                  name = "HomeDiscord";
                  receivers = [
                    {
                      uid = "b7e00da1-b9c7-4f72-bc95-1ef3e7e5b4cf";
                      type = "discord";
                      settings = {
                        url = "$__env{DISCORD_HOOK}";
                        use_discord_username = false;
                      };
                      disableResolveMessage = false;
                    }
                  ];
                }
              ];
            };
            policies.settings = {
              apiVersion = 1;
              policies = [
                {
                  orgId = 1;
                  receiver = "HomeDiscord";
                  group_by = [
                    "grafana_folder"
                    "alertname"
                  ];
                  group_wait = "30s";
                  group_interval = "5m";
                  repeat_interval = "4h";
                }
              ];
              # resetPolicies seems to happen after setting the above policies, effectively rolling back
              # any updates.
            };
          };

          datasources.settings.datasources = cfg.datasources;
          datasources.settings.deleteDatasources = cfg.deleteDatasources;
        };
      };
    };
  };
}
