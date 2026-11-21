{
  config,
  lib,
  options,
  ...
}:
{

  config = (
    lib.optionalAttrs (options ? preservation) {

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

      preservation = {
        enable = true;
        preserveAt."/persist" = {
          directories = [
            {
              directory = "/var/lib/systemd";
              inInitrd = true;
            }
            {
              directory = "/var/lib/nixos";
              inInitrd = true;
            }
            {
              directory = "/var/lib/private/systemd";
              mode = "0700";
              configureParent = true;
              parent.mode = "0700";
            }
          ]
          ++ lib.optionals (config.services.fail2ban.enable) [
            "/var/lib/fail2ban"
          ]
          ++ lib.optionals (config.services.vnstat.enable) [
            {
              directory = "/var/lib/vnstat";
              user = "vnstatd";
              group = "vnstatd";
            }
          ]
          ++ lib.optionals (config.services.userborn.enable) [
            "/var/lib/userborn"
          ]
          ++ lib.optionals (config.security.acme.certs != { }) [
            "/var/lib/acme"
          ]
          ++ lib.optionals (config.services.prometheus.enable) [
            config.services.prometheus.stateDir
          ];
          files = [
            {
              file = "/etc/ssh/ssh_host_rsa_key";
              how = "symlink";
              configureParent = true;
              inInitrd = true;
            }
            {
              file = "/etc/ssh/ssh_host_ed25519_key";
              how = "symlink";
              configureParent = true;
              inInitrd = true;
            }
            {
              file = "/etc/machine-id";
              inInitrd = true;
            }
            {
              file = "/etc/NIXOS";
              inInitrd = true;
            }
          ];
        };
      };
      systemd.suppressedSystemUnits = [ "systemd-machine-id-commit.service" ];
      fileSystems."/persist".neededForBoot = true;
    }
  );
}
