{
  pkgs,
  config,
  lib,
  ...
}:
{
  options.includes.postgresql.enable = lib.mkEnableOption "Enable PostgreSQL database server";

  config = lib.mkIf (config.includes.postgresql.enable) {
    services = {
      postgresql.enable = true;
      prometheus.exporters.postgres = {
        enable = true;
        listenAddress = "127.0.0.1";
        port = 9187;
        runAsLocalSuperUser = true;
      };
      vmagent.prometheusConfig.scrape_configs = [
        {
          job_name = "postgres";
          static_configs = [
            { targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.postgres.port}" ]; }
          ];
        }
      ];
    };

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "pg-refresh-collation" ''
        ${toString (
          map (database: " reindexdb -v -d  ${database};") config.services.postgresql.ensureDatabases
        )}
        sudo -u postgres ${lib.getExe' config.services.postgresql.package "psql"} -c '
        ALTER DATABASE "template1" REFRESH COLLATION VERSION;
        ${
          toString (
            map (
              database: "ALTER DATABASE ${database} REFRESH COLLATION VERSION;"
            ) config.services.postgresql.ensureDatabases
          )
        }'
      '')
    ];

    systemd = {
      services.postgresql-vacuum-analyze = {
        description = "Vacuum and analyze all PostgreSQL databases";
        serviceConfig = {
          ExecStart = "${lib.getExe' config.services.postgresql.package "psql"} -c 'VACUUM ANALYZE'";
          User = "postgres";
        };
        wantedBy = [ "timers.target" ];
        after = [ "postgresql.target" ];
        requires = [ "postgresql.target" ];
      };
      timers.postgresql-vacuum-analyze = {
        timerConfig = {
          OnCalendar = "03:00";
          Persistent = true;
          RandomizedDelaySec = "30m";
        };
        wantedBy = [ "timers.target" ];
      };
    };
  };
}
