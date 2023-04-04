# https://github.com/NixOS/nixpkgs/pull/201780
{
  config,
  options,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.nextcloud.notify_push;
  cfgN = config.services.nextcloud;
in {
  options.services.nextcloud.notify_push =
    {
      enable = lib.mkEnableOption (lib.mdDoc "Notify push");

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.nextcloud-notify_push;
        defaultText = lib.literalMD "pkgs.nextcloud-notify_push";
        description = lib.mdDoc "Which package to use for notify_push";
      };

      socketPath = lib.mkOption {
        type = lib.types.str;
        default = "/run/nextcloud-notify_push/sock";
        description = lib.mdDoc "Socket path to use for notify_push";
      };

      logLevel = lib.mkOption {
        type = lib.types.enum ["error" "warn" "info" "debug" "trace"];
        default = "error";
        description = lib.mdDoc "Log level";
      };
    }
    // (
      lib.listToAttrs (
        map
        (
          opt:
            lib.nameValuePair opt (options.services.nextcloud.config.${opt}
              // {
                default = config.services.nextcloud.config.${opt};
                defaultText = lib.mdDoc "config.services.nextcloud.config.${opt}";
              })
        ) [
          "dbtype"
          "dbname"
          "dbuser"
          "dbpassFile"
          "dbhost"
          "dbport"
          "dbtableprefix"
        ]
      )
    );

  config = lib.mkIf cfg.enable {
    systemd.services.nextcloud-notify_push = let
      nextcloudUrl = "http${lib.optionalString cfgN.https "s"}://${cfgN.hostName}";
    in {
      description = "Push daemon for Nextcloud clients";
      documentation = ["https://github.com/nextcloud/notify_push"];
      after = [
        "phpfpm-nextcloud.service"
        "redis-nextcloud.service"
      ];
      wantedBy = ["multi-user.target"];
      environment = {
        NEXTCLOUD_URL = nextcloudUrl;
        SOCKET_PATH = cfg.socketPath;
        DATABASE_PREFIX = cfg.dbtableprefix;
        LOG = cfg.logLevel;
      };
      postStart = ''
        ${cfgN.occ}/bin/nextcloud-occ notify_push:setup ${nextcloudUrl}/push
      '';
      script = let
        dbType =
          if cfg.dbtype == "pgsql"
          then "postgresql"
          else cfg.dbtype;
        dbUser = lib.optionalString (cfg.dbuser != null) cfg.dbuser;
        dbPass = lib.optionalString (cfg.dbpassFile != null) ":$DATABASE_PASSWORD";
        isSocket = lib.hasPrefix "/" (toString cfg.dbhost);
        dbHost = lib.optionalString (cfg.dbhost != null) (
          if isSocket
          then
            if dbType == "postgresql"
            then "?host=${cfg.dbhost}"
            else if dbType == "mysql"
            then "?socket=${cfg.dbhost}"
            else throw "unsupported dbtype"
          else "@${cfg.dbhost}"
        );
        dbName = lib.optionalString (cfg.dbname != null) "/${cfg.dbname}";
        dbUrl = "${dbType}://${dbUser}${dbPass}${lib.optionalString (!isSocket) dbHost}${dbName}${lib.optionalString isSocket dbHost}";
      in
        lib.optionalString (dbPass != "") ''
          export DATABASE_PASSWORD="$(<"${cfg.dbpassFile}")"
        ''
        + ''
          export DATABASE_URL="${dbUrl}"
          ${cfg.package}/bin/notify_push --glob-config '${cfgN.datadir}/config/config.php'
        '';
      serviceConfig = {
        User = "nextcloud";
        Group = "nextcloud";
        RuntimeDirectory = ["nextcloud-notify_push"];
      };
    };

    services.nginx.virtualHosts.${config.services.nextcloud.hostName}.locations."^~ /push/" = {
      proxyPass = "http://unix:${cfg.socketPath}";
      proxyWebsockets = true;
      recommendedProxySettings = true;
    };
  };
}
