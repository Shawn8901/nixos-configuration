{
  den.aspects.tank.nixos =
    {
      lib,
      pkgs,
      self',
      ...
    }:
    let
      device = {
        idVendor = "04fc";
        idProduct = "0c25";
        partition = "2";
      };
      mountPoint = "/media/usb_backup_ela";
      backupPath = "/media/daniela/";
      uid = "ela";

      backup-usb-Script = pkgs.writeShellScriptBin "backup-usb" ''
        BACKUP_SOURCE="${backupPath}"
        BACKUP_DEVICE="/dev/$1"
        MOUNT_POINT="${mountPoint}"

        if [ ! -d "$MOUNT_POINT" ]; then
          ${pkgs.coreutils-full}/bin/mkdir "$MOUNT_POINT";
        fi
        echo "Mount $BACKUP_DEVICE"
        ${pkgs.util-linux}/bin/mount -o uid=${uid},gid=users,umask=0022 -t auto "$BACKUP_DEVICE" "$MOUNT_POINT"

        echo "Starting RSYNC"
        ${lib.getExe pkgs.rsync} -Pauvi "$BACKUP_SOURCE" "$MOUNT_POINT"
        ${pkgs.coreutils-full}/bin/sync

        echo "Unmount $BACKUP_DEVICE"
        ${pkgs.udisks2}/bin/udisksctl unmount -b ''${BACKUP_DEVICE}

        sleep 1
        ${lib.getExe pkgs.beep}

        echo "Poweroff device"
        ${pkgs.udisks2}/bin/udisksctl power-off -b ''${BACKUP_DEVICE//[[:digit:]]}

        ${lib.getExe pkgs.beep}
      '';
    in
    {
      environment.systemPackages = [ pkgs.cifs-utils ];

      nixpkgs.config.packageOverrides = pkgs: {
        # ubuntu blacklists pc speaker as it annoys them
        kmod-blacklist-ubuntu = pkgs.kmod-blacklist-ubuntu.overrideAttrs (old: {
          patchPhase = ''
            sed -i '/blacklist pcspkr/d' ./modprobe.d/blacklist.conf
          '';
        });
      };

      boot.kernelModules = [ "pcspkr" ];

      services.udev.extraRules = ''
        SUBSYSTEM=="block", ACTION=="add", ATTRS{idVendor}=="${device.idVendor}", ATTRS{idProduct}=="${device.idProduct}", ATTR{partition}=="${device.partition}", TAG+="systemd", ENV{SYSTEMD_WANTS}="backup-usb@%k.service"
      '';

      systemd.services."backup-usb@" = {
        description = "Backups ${backupPath} to usb hdd";
        serviceConfig = {
          Type = "simple";
          GuessMainPID = false;
          ExecStart = "${lib.getExe backup-usb-Script} %I";
        };
      };
    };
}
