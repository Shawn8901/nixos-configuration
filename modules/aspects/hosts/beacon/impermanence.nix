{
  den.aspects.beacon.nixos =
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
          "/var/lib/acme"
          "/var/lib/alsa"
          "/var/lib/fail2ban"
          "/var/lib/hass"
          "/var/lib/nixos"
          "/var/lib/private/"
          "/var/lib/prometheus2"
          "/var/lib/systemd"
          "/var/lib/thread"
          "/var/lib/userborn"
          "/var/lib/vnstat"
        ];
        files = [ "/etc/machine-id" ];
      };
    };
}
