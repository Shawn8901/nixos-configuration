{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (lib) types mkEnableOption mkOption mkIf;

  cfg = config.shawn8901.grafana;
in {
  options = {
    shawn8901.grafana = {
      enable = mkEnableOption "Enables a preconfigured grafana instance";
      hostName = mkOption {
        type = types.str;
        description = "full qualified hostname of the grafana instance";
      };
      credentialsFile = mkOption {
        type = types.path;
      };
      datasources = mkOption {
        type = types.listOf types.raw;
      };
    };
  };
  config = mkIf cfg.enable {
    systemd.services.grafana.serviceConfig.EnvironmentFile = [cfg.credentialsFile];
    networking.firewall = {
      allowedUDPPorts = [443];
      allowedTCPPorts = [80 443];
    };
    services = {
      nginx = {
        enable = true;
        package = pkgs.nginxQuic;
        recommendedGzipSettings = true;
        recommendedOptimisation = true;
        recommendedTlsSettings = true;
        virtualHosts = {
          "${config.services.grafana.settings.server.domain}" = {
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
      };
      postgresql = {
        ensureDatabases = [
          "${config.services.grafana.settings.database.name}"
        ];
        ensureUsers = [
          {
            name = "${config.services.grafana.settings.database.user}";
            ensurePermissions = {"DATABASE ${config.services.grafana.settings.database.name}" = "ALL PRIVILEGES";};
          }
        ];
      };
      grafana = {
        enable = true;
        settings = {
          server = {
            domain = cfg.hostName;
            http_addr = "127.0.0.1";
            http_port = 3001;
            root_url = "https://${cfg.hostName}/";
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
            host = "pointjig.de:465";
            user = "noreply@pointjig.de";
            password = "$__env{SMTP_PASSWORD}";
            from_address = "noreply@pointjig.de";
          };
          analytics = {
            check_for_updates = false;
            reporting_enabled = false;
          };
          alerting.enabled = false;
          unified_alerting.enabled = true;
        };
        provision = {
          enable = true;
          datasources.settings.datasources = cfg.datasources;
        };
      };
    };
  };
}