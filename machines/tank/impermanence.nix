{ lib, ... }:
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
  boot.initrd.postResumeCommands = lib.mkAfter ''
    echo "Rollback rpool to blank snapshot"
    zfs rollback -r rpool/local/root@blank
  '';

  security.sudo.extraConfig = ''
    Defaults lecture = never
  '';

  environment.etc."machine-id".source = "/persist/etc/machine-id";
  environment.etc."/etc/nixos".source = "/persist/etc/nixos";

  fileSystems = lib.mkMerge [
    {
      "/var/lib/nixos" = {
        device = "/persist/var/lib/nixos";
        noCheck = true;
        options = [ "bind" ];
      };
    }
    (makePersistMount "/var/lib/alsa")
    (makePersistMount "/var/lib/stalwart-mail")
    (makePersistMount "/var/lib/attic")
    (makePersistMount "/var/lib/acme")
    (makePersistMount "/var/lib/fail2ban")
    (makePersistMount "/var/lib/vnstat")
    (makePersistMount "/var/lib/samba")
    (makePersistMount "/var/lib/hydra")
    (makePersistMount "/var/lib/prometheus2")
    (makePersistMount "/var/lib/systemd")
  ];
}
