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
      starship = {
        enable = true;
        interactiveOnly = true;
        settings = {
          command_timeout = 2000;
          # Don"t print a new line at the start of the prompt
          add_newline = false;

          # Wait 10 milliseconds for starship to check files under the current directory.
          scan_timeout = 10;

          directory = {
            truncation_length = 3;
            truncation_symbol = "…";
          };

          #to display the hostname before the character line
          hostname = {
            ssh_only = false;
            style = "blue";
            format = "[$hostname]($style) in ";
            disabled = false;
          };
          #the character at the start of line where command is entered
          character = {
            error_symbol = "[✗](bold red)";
            vicmd_symbol = "[V](bold green)";
          };

          git_branch = {
            symbol = "🌿 ";
          };
          git_commit = {
            disabled = false;
          };

          git_status = {
            ahead = "⇡ $count";
            diverged = "⇕ ⇡ $ahead_count ⇣ $behind_count";
            behind = "⇣ $count";
          };
          memory_usage = {
            format = "$symbol[$ram( | $swap)]($style) ";
            symbol = "🌒️";
            threshold = 50;
            style = "bold dimmed white";
            disabled = false;
          };
        };
      };
      zsh = {
        enable = true;
        enableCompletion = true;
        enableBashCompletion = true;
        enableGlobalCompInit = true;
        syntaxHighlighting.enable = true;
        autosuggestions.enable = true;
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
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFmwxYRglh8MIGWZvQR/6mYCO7NTTJFnrQq7j5pjfkvZ smartphone"
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
