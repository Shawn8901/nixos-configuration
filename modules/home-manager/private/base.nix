{ lib, config, ... }:
let
  inherit (lib) mkDefault;
in
{
  home.stateVersion = "23.05";

  programs = {
    zsh = {
      enable = true;
      dotDir = "${config.xdg.configHome}/zsh";
    };
    dircolors = {
      enable = true;
      enableZshIntegration = true;
    };
    man.enable = mkDefault false;
  };
  manual.manpages.enable = mkDefault false;
}
