{
  cfg.nextcloud.nixos =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {

      imports = [ ./_nuschtos_nextcloud.nix ];

      sops.secrets = {
        nextcloud-admin = {
          owner = "nextcloud";
          group = "nextcloud";
        };
        prometheus-nextcloud = {
          owner = config.services.prometheus.exporters.nextcloud.user;
          inherit (config.services.prometheus.exporters.nextcloud) group;
        };
      };

      networking.firewall = {
        allowedUDPPorts = [ 443 ];
        allowedTCPPorts = [
          80
          443
        ];
      };

      systemd.services.nextcloud-setup.after = [ "nginx-config-reload.service" ];

      services = {
        nextcloud = {
          notify_push = {
            enable = lib.mkDefault true;
            bendDomainToLocalhost = true;
          };
          enable = true;
          configureRedis = true;
          https = true;
          autoUpdateApps.enable = true;
          autoUpdateApps.startAt = "Sun 14:00:00";
          maxUploadSize = "1G";
          database.createLocally = true;
          config = {
            dbtype = "pgsql";
            dbuser = "nextcloud";
            dbhost = "/run/postgresql";
            dbname = "nextcloud";
            adminuser = "admin";
            adminpassFile = config.sops.secrets.nextcloud-admin.path;
          };
          caching = {
            apcu = false;
            memcached = false;
          };
          phpOptions = {
            "opcache.enable" = "1";
            "opcache.save_comments" = "1";
          };
          settings = {
            "overwrite.cli.url" = "https://${config.services.nextcloud.hostName}";
            default_phone_region = "DE";
            maintenance_window_start = lib.mkDefault "1";
          };
        };
        postgresql = {
          ensureDatabases = [ "${config.services.nextcloud.config.dbname}" ];
          ensureUsers = [
            {
              name = "${config.services.nextcloud.config.dbuser}";
              ensureDBOwnership = true;
            }
          ];
        };
        nginx = {
          enable = lib.mkDefault true;
          recommendedGzipSettings = true;
          recommendedOptimisation = true;
          recommendedTlsSettings = true;
          recommendedProxySettings = true;
          virtualHosts."${config.services.nextcloud.hostName}" = {
            enableACME = true;
            forceSSL = true;
            http3 = true;
            kTLS = true;
          };
        };
        prometheus.exporters.nextcloud = {
          enable = lib.mkDefault true;
          listenAddress = "localhost";
          port = 9205;
          url = "https://${config.services.nextcloud.hostName}";
          passwordFile = config.sops.secrets.prometheus-nextcloud.path;
        };

        vmagent.prometheusConfig.scrape_configs =
          lib.mkIf config.services.prometheus.exporters.nextcloud.enable
            [
              {
                job_name = "nextcloud";
                static_configs = [
                  { targets = [ "localhost:${toString config.services.prometheus.exporters.nextcloud.port}" ]; }
                ];
              }
            ];
      };
    };
}
