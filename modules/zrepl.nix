{
  config,
  lib,
  ...
}:
let
  servePorts =
    zrepl:
    map (serveEntry: lib.toInt (lib.removePrefix ":" serveEntry.serve.listen)) (
      lib.filter (builtins.hasAttr "serve") (zrepl.settings.jobs or [ ])
    );
  cfg = config.includes.zrepl;
in
{
  options.includes.zrepl = {
    enable = lib.mkEnableOption "Enable zrepl configurations" // {
      default = config.boot.supportedFilesystems.zfs or false;
    };
    monitoringPort = lib.mkOption {
      type = lib.types.port;
      default = 9811;
      description = "The port for zrepl monitoring to listen on";
    };
  };

  config = lib.mkIf (cfg.enable) {
    networking.firewall.allowedTCPPorts = servePorts config.services.zrepl;
    services = {
      zrepl = {
        enable = true;
        settings.global = {
          logging = [
            {
              type = "stdout";
              level = "warn";
              format = "human";
            }
          ];
          monitoring = [
            {
              type = "prometheus";
              listen = ":${toString cfg.monitoringPort}";
              listen_freebind = true;
            }
          ];
        };
      };
      vmagent.prometheusConfig.scrape_configs = [
        {
          job_name = "zrepl";
          static_configs = [
            {
              targets = [
                "127.0.0.1:${toString cfg.monitoringPort}"
              ];
            }
          ];
        }
      ];
    };
  };
}
