{
  config,
  pkgs,
  lib,
  ...
}:
{
  options.includes.desktop.gaming.enable = lib.mkEnableOption "Enable gaming configurations";

  config = lib.mkIf (config.includes.desktop.gaming.enable) {

    nixpkgs.config.allowUnfreePackages = [
      "steam"
      "steam-unwrapped"
      "teamspeak6-client"
    ];

    environment = {
      sessionVariables = {
        PROTON_ENABLE_WAYLAND = "1";
        PROTON_USE_NTSYNC = "1";
        WINEFSYNC = "1";
        WINEDEBUG = "-all";
      };
      systemPackages = [ pkgs.teamspeak6-client ];
    };

    boot.kernel.sysctl = {
      # https://github.com/ValveSoftware/Proton/wiki/Requirements#increasing-the-maximum-number-of-memory-map-areas-a-process-may-have
      "vm.max_map_count" = 2147483642;
    };
    programs.steam = {
      enable = true;
      extraCompatPackages = [ pkgs.proton-ge-bin ];
      package = pkgs.steam.override {
        extraLibraries = p: [
          # Fix Unity Fonts
          (pkgs.runCommand "share-fonts" { preferLocalBuild = true; } ''
            mkdir -p "$out/share/fonts"
            font_regexp='.*\.\(ttf\|ttc\|otf\|pcf\|pfa\|pfb\|bdf\)\(\.gz\)?'
            find ${
              toString [
                pkgs.liberation_ttf
                pkgs.dejavu_fonts
              ]
            } -regex "$font_regexp" \
              -exec ln -sf -t "$out/share/fonts" '{}' \;
          '')
          p.getent
        ];
      };
    };
    boot.kernelModules = [ "ntsync" ];
  };
}
