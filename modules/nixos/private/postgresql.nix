{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.shawn8901.postgresql;
  inherit (lib)
    mkEnableOption
    mkOption
    mkPackageOption
    mkDefault
    mkIf
    types
    ;
in
{
  options = {
    shawn8901.postgresql = {
      enable = mkEnableOption "Enables a preconfigured postgresql instance";
      package = mkPackageOption pkgs "postgresql_16" { };
      dataDir = mkOption {
        type = types.str;
        default = "/var/lib/postgresql/${cfg.package.psqlSchema}";
      };
    };
  };

  config = mkIf cfg.enable {
    services = {
      postgresql = {
        enable = mkDefault true;
        inherit (cfg) dataDir package;
      };
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
      services = {
        postgresql-vacuum-analyze = lib.mkMerge [
          {
            description = "Vacuum and analyze all PostgreSQL databases";
            serviceConfig = {
              ExecStart = "${lib.getExe' cfg.package "psql"} -c 'VACUUM ANALYZE'";
              User = "postgres";
            };
            wantedBy = [ "timers.target" ];
          }
          (lib.optionalAttrs (lib.versionOlder config.system.nixos.release "25.11") {
            after = [ "postgresql.service" ];
            requires = [ "postgresql.service" ];
          })

          (lib.optionalAttrs (!lib.versionOlder config.system.nixos.release "25.11") {
            after = [ "postgresql.target" ];
            requires = [ "postgresql.target" ];
          })

        ];
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
