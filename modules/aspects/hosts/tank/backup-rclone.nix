{
  den.aspects.tank.nixos =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      makeRcloneConfig = sourceDir: destDir: {
        systemd = {
          services.${sourceDir} = {
            requires = [ "network-online.target" ];
            after = [ "network-online.target" ];
            description = "Copy nextcloud stuff to dropbox";
            serviceConfig = {
              Type = "oneshot";
              User = "shawn";
              ExecStart = "${lib.getExe pkgs.rclone} copy ${sourceDir} ${destDir}";
            };
          };
          timers.${sourceDir} = {
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = [ "daily" ];
              Persistent = true;
              OnBootSec = "15min";
            };
          };
        };
      };
    in
    makeRcloneConfig "${config.services.nextcloud.home}/data/shawn/files/" "dropbox:";
}
