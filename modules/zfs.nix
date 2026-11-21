{ config, lib, ... }:
let
  cfg = config.includes.zfs;
in
{
  options.includes.zfs.enable = lib.mkEnableOption "Enable zfs configurations" // {
    default = config.boot.supportedFilesystems.zfs or false;
  };

  config = lib.mkIf (cfg.enable) {

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
            { targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.zfs.port}" ]; }
          ];
        }
      ];
      prometheus.exporters.zfs = {
        enable = true;
        listenAddress = "127.0.0.1";
      };
    };
  };
}
