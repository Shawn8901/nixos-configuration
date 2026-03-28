{
  cfg.monitoree.provides.vmagent.nixos =
    { config, lib, ... }:
    {
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
                  { targets = [ "localhost:${toString config.services.prometheus.exporters.node.port}" ]; }
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
          smartctl = {
            enable = config.services.smartd.enable;
            listenAddress = "localhost";
            maxInterval = "5m";
          };
        };
      };
    };
}
