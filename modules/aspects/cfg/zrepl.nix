{ lib, ... }:
let
  servePorts =
    zrepl:
    map (serveEntry: lib.toInt (lib.removePrefix ":" serveEntry.serve.listen)) (
      lib.filter (builtins.hasAttr "serve") (zrepl.settings.jobs or [ ])
    );

  monitoringPort = 9811;
in
{
  cfg.zrepl.nixos =
    { config, ... }:
    {
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
                listen = ":${toString monitoringPort}";
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
                  "localhost:${toString monitoringPort}"
                ];
              }
            ];
          }
        ];
      };
    };
}
