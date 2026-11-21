{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.rclone;
in
{
  options.services.rclone = {
    enable = lib.mkEnableOption "Enable rclone backup service";
    sourceDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/shawn/nextcloud/data/shawn/files/";
      description = "Source directory to backup";
    };
    destDir = lib.mkOption {
      type = lib.types.str;
      default = "dropbox:";
      description = "Destination directory to backup to";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd = {
      services.${cfg.sourceDir} = {
        requires = [ "network-online.target" ];
        after = [ "network-online.target" ];
        description = "Copy nextcloud stuff to dropbox";
        serviceConfig = {
          Type = "oneshot";
          User = "shawn";
          ExecStart = "${lib.getExe pkgs.rclone} copy ${cfg.sourceDir} ${cfg.destDir}";
        };
      };
      timers.${cfg.sourceDir} = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = [ "daily" ];
          Persistent = true;
          OnBootSec = "15min";
        };
      };
    };
  };
}
