{
  config,
  lib,
  flakeConfig,
  ...
}:
let
  inherit (lib) optionals mkMerge optionalAttrs;
in
{
  sops.secrets = {
    vmagent = {
      sopsFile = ../../../../files/secrets-base.yaml;
    };
  };

  services = {
    vmagent = {
      enable = true;
      prometheusConfig = {
        global = {
          scrape_interval = "1m";
          scrape_timeout = "30s";
        };
        scrape_configs =
          [
            {
              job_name = "node";
              static_configs = [
                { targets = [ "localhost:${toString config.services.prometheus.exporters.node.port}" ]; }
              ];
            }
          ]
          ++ lib.optionals config.services.prometheus.exporters.zfs.enable [
            {
              job_name = "zfs";
              static_configs = [
                { targets = [ "localhost:${toString config.services.prometheus.exporters.zfs.port}" ]; }
              ];
            }
          ]
          ++ optionals config.services.prometheus.exporters.smartctl.enable [
            {
              job_name = "smartctl";
              static_configs = [
                { targets = [ "localhost:${toString config.services.prometheus.exporters.smartctl.port}" ]; }
              ];
            }
          ]
          ++ optionals config.services.zrepl.enable [
            {
              job_name = "zrepl";
              static_configs = [
                {
                  targets = [
                    "localhost:${toString (flakeConfig.shawn8901.zrepl.monitoringPorts config.services.zrepl)}"
                  ];
                }
              ];
            }
          ];
      };
      remoteWrite = {
        url = lib.mkDefault "https://vm.pointjig.de/api/v1/write";
        basicAuthUsername = "vm";
        basicAuthPasswordFile = config.sops.secrets.vmagent.path;
      };
      extraArgs = [ "-remoteWrite.label=instance=${config.networking.hostName}" ];
    };

    prometheus.exporters = mkMerge [
      {
        node = {
          enable = true;
          listenAddress = "localhost";
          port = 9101;
          enabledCollectors = [
            "systemd"
            "processes"
            "interrupts"
            "cgroups"
            "hwmon"
          ];
        };
      }
      (optionalAttrs (config.boot.supportedFilesystems.zfs or false) {
        zfs = {
          enable = true;
          listenAddress = "localhost";
        };
      })
      (optionalAttrs config.services.smartd.enable {
        smartctl = {
          enable = true;
          listenAddress = "localhost";
          maxInterval = "5m";
        };
      })
    ];
  };
}
