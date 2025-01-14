{ config, ... }:
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

  environment.etc."machine-id".source = "/persist/etc/machine-id";
  environment.etc."nixos".source = "/persist/etc/nixos";

  security.sudo.extraConfig = ''
    Defaults lecture = never
  '';

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/etc/NetworkManager/system-connections"
      "/var/lib/bluetooth"
      "/var/lib/cups"
      "/var/lib/NetworkManager"
      "/var/lib/nixos"
      "/var/lib/prometheus2"
      "/var/lib/systemd"
      "/var/lib/upower"
    ];
    files = [ "/etc/machine-id" ];
  };
}
