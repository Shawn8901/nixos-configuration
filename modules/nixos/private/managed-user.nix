{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.shawn8901.managed-user;
in
{
  options = {
    shawn8901.managed-user = {
      enable = mkEnableOption "preconfigured users" // {
        default = config ? home-manager;
      };
    };
  };
  config = mkIf cfg.enable {

    sops.secrets = {
      shawn = {
        sopsFile = ../../../files/secrets-managed.yaml;
        neededForUsers = true;
      };
      root = {
        sopsFile = ../../../files/secrets-managed.yaml;
        neededForUsers = true;
      };
    };

    programs = {
      fzf = {
        fuzzyCompletion = true;
        keybindings = true;
      };
      zsh = {
        enable = true;
        enableCompletion = true;
        enableBashCompletion = true;
        enableGlobalCompInit = true;
        syntaxHighlighting.enable = true;
        autosuggestions.enable = true;
        promptInit = ''
          source "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme"
          source "${../../../files/p10k.zsh}"

        '';
        interactiveShellInit = ''
          source "${pkgs.zsh-history-substring-search}/share/zsh-history-substring-search/zsh-history-substring-search.zsh"

          bindkey '^[[1;5C' forward-word        # ctrl right
          bindkey '^[[1;5D' backward-word       # ctrl left
          bindkey '^H' backward-kill-word
          bindkey '5~' kill-word
        '';
      };
    };

    users = {
      mutableUsers = false;
      defaultUserShell = pkgs.zsh;
      users = {
        root.hashedPasswordFile = config.sops.secrets.root.path;
        shawn = {
          isNormalUser = true;
          group = "users";
          extraGroups = [ "wheel" ];
          uid = 1000;
          openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMguHbKev03NMawY9MX6MEhRhd6+h2a/aPIOorgfB5oM shawn"
          ];
          hashedPasswordFile = config.sops.secrets.shawn.path;
        };
      };
    };

    # Needed to access secrets for the builder.
    nix.settings.trusted-users = [ "shawn" ];

    environment.systemPackages = [ pkgs.fzf ]; # Used by zsh-interactive-cd
  };
}
