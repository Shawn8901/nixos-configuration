{ config, lib, ... }:

let
  makePersistMount = path: {
    "${path}" = {
      device = "/persist${path}";
      options = [
        "bind"
        "noauto"
        "x-systemd.automount"
      ];
    };
  };
in
{
  boot.initrd.systemd.services.initrd-rollback-root = {
    after = [ "zfs-import-rpool.service" ];
    requires = [ "zfs-import-rpool.service" ];
    before = [ "sysroot.mount" ];
    wantedBy = [ "initrd.target" ];
    description = "Rollback root fs";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${config.boot.zfs.package}/sbin/zfs rollback -r rpool/local/root@blank";
    };
  };

  # boot.initrd.postDeviceCommands = lib.mkAfter ''
  #   zfs rollback -r rpool/local/root@blank
  # '';

  environment.etc."machine-id".source = "/persist/etc/machine-id";
  environment.etc."nixos".source = "/persist/etc/nixos";

  security.sudo.extraConfig = ''
    Defaults lecture = never
  '';

  fileSystems = lib.mkMerge [
    {
      "/var/lib/nixos" = {
        device = "/persist/var/lib/nixos";
        noCheck = true;
        options = [ "bind" ];
      };
    }
    (makePersistMount "/var/lib/bluetooth")
    (makePersistMount "/var/lib/NetworkManager")
    (makePersistMount "/var/lib/libvirt")
    (makePersistMount "/var/lib/cups")
    (makePersistMount "/var/lib/systemd")
    (makePersistMount "/var/lib/prometheus2")
    (makePersistMount "/var/lib/upower")
  ];
}
