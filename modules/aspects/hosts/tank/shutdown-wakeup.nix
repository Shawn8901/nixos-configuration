{
  den.aspects.tank.nixos =
    {
      lib,
      pkgs,
      ...
    }:
    let
      wakeupPackage = pkgs.writeShellScriptBin "rtc-helper" ''
        ${pkgs.util-linux}/bin/rtcwake -m no -t $(${pkgs.coreutils-full}/bin/date +%s -d 'tomorrow ${wakeupTime}')
      '';

      shutdownTime = "0:00:00";
      wakeupTime = "16:00:00";

    in
    {
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
          timerConfig.OnCalendar = [ "*-*-* ${shutdownTime}" ];
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
            OnCalendar = [ "*-*-* ${wakeupTime}" ];
          };
        };
      };
    };
}
