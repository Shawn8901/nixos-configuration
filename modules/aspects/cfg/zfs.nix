{
  cfg.zfs.nixos =
    { config, lib, ... }:
    {
      systemd.tmpfiles.rules = [
        "d /etc/exports.d 0750 root root" # needed by zfs to run 'zfs mount -a'
      ];

      services = {
        zfs = {
          trim.enable = lib.mkDefault true;
          autoScrub.enable = true;
        };
        vmagent.prometheusConfig.scrape_configs = [
          {
            job_name = "zfs";
            static_configs = [
              { targets = [ "localhost:${toString config.services.prometheus.exporters.zfs.port}" ]; }
            ];
          }
        ];
        prometheus.exporters.zfs = {
          enable = config.boot.supportedFilesystems.zfs or false;
          listenAddress = "localhost";
        };
      };
    };
}
