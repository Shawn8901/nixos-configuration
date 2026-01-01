{
  pkgs,
  lib,
  ...
}:
{
  shawn8901.desktop.enable = true;

  home.packages = [
    pkgs.keymapp
    pkgs.teamspeak6-client
    pkgs.portfolio
    pkgs.attic-client
    #pkgs.pytr
    #fPkgs.jameica-fhs
    pkgs.jameica
    pkgs.makemkv
    pkgs.libation
    (pkgs.asunder.override { mp3Support = true; })
    pkgs.deezer-enhanced
    pkgs.cifs-utils
  ];

  systemd.user.services.attic-watch-store = {
    Unit = {
      Description = "Upload all store content to binary catch";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
    Service = {
      ExecStart = "${lib.getExe pkgs.attic-client} watch-store nixos";
    };
  };

  programs.zsh.siteFunctions.cherryPick = "gh pr diff --patch $1 | git am";
  programs.zsh.shellAliases =
    let
      mount_script =
        path: credential:
        "sudo mount -t cifs //tank.fritz.box/${path} /media/nas -o credentials=${credential},iocharset=utf8,uid=1000,gid=100,forcegid,forceuid,vers=3.0";
    in
    {
      nas_mount = (mount_script "joerg" "/etc/samba/credentials_shawn");
      nas_mount_ela = (mount_script "ela" "/etc/samba/credentials_ela");
      nas_umount = "sudo umount /media/nas";
    };

  systemd.user.tmpfiles.rules = [
    "d /media/nas 0750"
  ];
}
