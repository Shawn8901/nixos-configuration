{
  den.aspects.watchtower.nixos =
    { config, pkgs, ... }:
    {
      sops.secrets.grafana-env = {
        owner = "grafana";
        group = "grafana";
      };

      systemd.services.grafana.serviceConfig.EnvironmentFile = [ config.sops.secrets.grafana-env.path ];
      networking.firewall = {
        allowedUDPPorts = [ 443 ];
        allowedTCPPorts = [
          80
          443
        ];
      };
      services = {
        nginx = {
          enable = true;
          recommendedGzipSettings = true;
          recommendedOptimisation = true;
          recommendedTlsSettings = true;
          recommendedProxySettings = true;
          virtualHosts."${config.services.grafana.settings.server.domain}" = {
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
          declarativePlugins = with pkgs.grafanaPlugins; [
            grafana-metricsdrilldown-app
            grafana-exploretraces-app
            grafana-pyroscope-app
            grafana-lokiexplore-app
            victoriametrics-logs-datasource
            victoriametrics-metrics-datasource
          ];
          settings = {
            server = rec {
              domain = "grafana.pointjig.de";
              http_addr = "127.0.0.1";
              http_port = 3001;
              root_url = "https://${domain}/";
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

            datasources.settings.datasources = [
              {
                name = "VictoriaMetrics Metrics";
                type = "victoriametrics-metrics-datasource";
                url = "http://${config.services.victoriametrics.listenAddress}";
                basicAuth = true;
                basicAuthUser = "vm";
                isDefault = true;
                secureJsonData.basicAuthPassword = "$VM_DATASOURCE_PASSWORD";
              }
              {
                name = "VictoriaLogs";
                type = "victoriametrics-logs-datasource";
                url = "http://${config.services.victorialogs.listenAddress}";
                basicAuth = true;
                basicAuthUser = "vl";
                secureJsonData.basicAuthPassword = "$VL_DATASOURCE_PASSWORD";
              }
            ];
          };
        };
      };
    };
}
