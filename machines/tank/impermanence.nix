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

  security.sudo.extraConfig = ''
    Defaults lecture = never
  '';

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/var/lib/private"
      "/var/lib/acme"
      "/var/lib/alsa"
      "/var/lib/attic"
      "/var/lib/fail2ban"
      "/var/lib/hydra"
      "/var/lib/immich"
      "/var/lib/meilisearch"
      "/var/lib/nixos"
      "/var/lib/openarchiver"
      "/var/lib/prometheus2"
      "/var/lib/samba"
      "/var/lib/stalwart-mail"
      "/var/lib/systemd"
      "/var/lib/tika"
      "/var/lib/vnstat"
    ];
    files = [ "/etc/machine-id" ];
  };

}
