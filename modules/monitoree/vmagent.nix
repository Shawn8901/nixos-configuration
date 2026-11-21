{ config, lib, ... }:
{
  options.includes.monitoree.vmagent.enable = lib.mkEnableOption "Enables vmagent monitoree";

  config = lib.mkIf (config.includes.monitoree.vmagent.enable) {

    sops.secrets.vmagent.sopsFile = ./secrets.yaml;
    services = {
      vmagent = {
        enable = true;
        prometheusConfig = {
          global = {
            scrape_interval = "1m";
            scrape_timeout = "30s";
          };
          scrape_configs = [
            {
              job_name = "node";
              static_configs = [
                { targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ]; }
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
      prometheus.exporters = {
        node = {
          enable = true;
          listenAddress = "127.0.0.1";
          port = 9101;
          enabledCollectors = [
            "systemd"
            "processes"
            "interrupts"
            "cgroups"
            "hwmon"
          ];
        };
        smartctl = {
          enable = config.services.smartd.enable;
          listenAddress = "127.0.0.1";
          maxInterval = "5m";
        };
      };
    };
  };
}
