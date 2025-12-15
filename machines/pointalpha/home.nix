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
}
