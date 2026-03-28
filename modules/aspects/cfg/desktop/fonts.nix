{
  cfg.desktop.provides.fonts.nixos =
    { lib, pkgs, ... }:
    {
      fonts = {
        fontconfig = {
          enable = lib.mkDefault true;
          hinting.autohint = true;
          cache32Bit = true;
          subpixel.lcdfilter = "light";
          defaultFonts = {
            emoji = [ "Noto Color Emoji" ];
            serif = [ "Noto Serif" ];
            sansSerif = [ "Noto Sans" ];
            monospace = [ "Noto Sans Mono" ];
          };
        };
        enableDefaultPackages = lib.mkDefault true;
        packages = [
          pkgs.noto-fonts
        ]
        ++ (with pkgs.nerd-fonts; [
          noto
          liberation
          meslo-lg
          liberation
        ]);
      };
    };
}
