{ lib, ... }:
{
  boot.initrd.postResumeCommands = lib.mkAfter ''
    echo "Rollback rpool to blank snapshot"
    zfs rollback -r rpool/local/root@blank
  '';

  security.sudo.extraConfig = ''
    Defaults lecture = never
  '';

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/var/lib/acme"
      "/var/lib/alsa"
      "/var/lib/attic"
      "/var/lib/fail2ban"
      "/var/lib/hydra"
      "/var/lib/immich"
      "/var/lib/nixos"
      "/var/lib/prometheus2"
      "/var/lib/samba"
      "/var/lib/stalwart-mail"
      "/var/lib/systemd"
      "/var/lib/vaultwarden"
      "/var/lib/vnstat"
    ];
    files = [ "/etc/machine-id" ];
  };

}
