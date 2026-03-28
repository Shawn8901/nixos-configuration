{ den, ... }:
{
  cfg.shell = {
    includes = [ (den.provides.user-shell "zsh") ];

    homeManager =
      { config, ... }:
      {
        programs.zsh = {
          enable = true;
          dotDir = "${config.xdg.configHome}/zsh";
        };
      };
    nixos =
      { pkgs, ... }:
      {
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
        environment.systemPackages = [ pkgs.fzf ];
      };
  };
}
