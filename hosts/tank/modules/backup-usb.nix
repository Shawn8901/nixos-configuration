{
  lib,
  pkgs,
  config,
  ...
}:
let
  backup-usb-Script = pkgs.writeShellScriptBin "backup-usb" ''
    BACKUP_DEVICE="/dev/$1"
    BACKUP_SOURCE="$2"
    MOUNT_POINT="$3"
    UID="$4";

    if [ ! -d "$MOUNT_POINT" ]; then
      ${pkgs.coreutils-full}/bin/mkdir "$MOUNT_POINT";
    fi
    echo "Mount $BACKUP_DEVICE"
    ${pkgs.util-linux}/bin/mount -o uid=$UID,gid=users,umask=0022 -t auto "$BACKUP_DEVICE" "$MOUNT_POINT"

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

  cfg = config.services.backup-usb;
in
{

  options.services.backup-usb = {
    enable = lib.mkEnableOption "Enable backup-usb service";
    device = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        idVendor = "04fc";
        idProduct = "0c25";
        partition = "2";
      };
      description = "USB device to backup to";
    };
    mountPoint = lib.mkOption {
      type = lib.types.str;
      default = "/media/usb_backup_ela";
      description = "Mount point for the USB device";
    };
    backupPath = lib.mkOption {
      type = lib.types.str;
      default = "/media/daniela/";
      description = "Path to backup";
    };
    uid = lib.mkOption {
      type = lib.types.str;
      default = "ela";
      description = "User ID to use for mounting the USB device";
    };
  };

  config = lib.mkIf cfg.enable {
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
      SUBSYSTEM=="block", ACTION=="add", ATTRS{idVendor}=="${cfg.device.idVendor}", ATTRS{idProduct}=="${cfg.device.idProduct}", ATTR{partition}=="${cfg.device.partition}", TAG+="systemd", ENV{SYSTEMD_WANTS}="backup-usb@%k.service"
    '';

    systemd.services."backup-usb@" = {
      description = "Backups ${cfg.backupPath} to usb hdd";
      serviceConfig = {
        Type = "simple";
        GuessMainPID = false;
        ExecStart = "${lib.getExe backup-usb-Script} %I ${cfg.backupPath} ${cfg.mountPoint} ${cfg.uid}";
      };
    };
  };
}
