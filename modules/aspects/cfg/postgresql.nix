{
  cfg.postgresql.nixos =
    { config, lib, ... }:
    {
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
              { targets = [ "localhost:${toString config.services.prometheus.exporters.postgres.port}" ]; }
            ];
          }
        ];
      };

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
