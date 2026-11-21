{
  config,
  lib,
  ...
}:
{
  options.includes.shell.enable = lib.mkEnableOption "Enable shell configuration";

  config = lib.mkIf (config.includes.shell.enable) {
    programs = {
      bash = {
        interactiveShellInit = ''
          shopt -s histappend
          HISTCONTROL=ignoreboth:erasedups
          HISTSIZE=100000
          HISTFILESIZE=100000
          PROMPT_COMMAND="history -a; history -c; history -r; $PROMPT_COMMAND"
        '';
        blesh.enable = true;
      };
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
    };
  };
}
