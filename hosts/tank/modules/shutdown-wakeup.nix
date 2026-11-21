{
  config,
  lib,
  pkgs,
  ...
}:
let
  wakeupPackage = pkgs.writeShellScriptBin "rtc-helper" ''
    ${pkgs.util-linux}/bin/rtcwake -m no -t $(${pkgs.coreutils-full}/bin/date +%s -d 'tomorrow ${cfg.wakeupTime}')
  '';
  cfg = config.services.shutdownWakeup;
in
{
  options.services.shutdownWakeup = {
    enable = lib.mkEnableOption "Enable scheduled shutdown and wakeup" // {
      default = true;
    };
    shutdownTime = lib.mkOption {
      type = lib.types.str;
      default = "0:00:00";
      description = "Time to shutdown the system (24h format)";
    };
    wakeupTime = lib.mkOption {
      type = lib.types.str;
      default = "20:00:00";
      description = "Time to wakeup the system (24h format)";
    };
  };

  config = lib.mkIf (cfg.enable) {
    systemd = {
      services.sched-shutdown = {
        description = "Scheduled shutdown";
        serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.systemd}/bin/systemctl --force poweroff";
        };
      };
      timers.sched-shutdown = {
        wantedBy = [ "timers.target" ];
        partOf = [ "sched-shutdown.service" ];
        timerConfig.OnCalendar = [ "*-*-* ${cfg.shutdownTime}" ];
      };

      services.rtcwakeup = {
        description = "Automatic wakeup";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe wakeupPackage;
        };
      };
      timers.rtcwakeup = {
        wantedBy = [ "timers.target" ];
        partOf = [ "sched-shutdown.service" ];
        timerConfig = {
          Persistent = true;
          OnBootSec = "1min";
          OnCalendar = [ "*-*-* ${cfg.wakeupTime}" ];
        };
      };
    };
  };
}
