{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.includes.desktop.printer.enable = lib.mkEnableOption "Enable printer configurations";

  config = lib.mkIf (config.includes.desktop.printer.enable) {

    nixpkgs.config.allowUnfreePackages = [ "epsonscan2" ];

    hardware.sane = {
      enable = true;
      extraBackends = [
        (pkgs.epsonscan2.override {
          withNonFreePlugins = true;
          withGui = true;
        })
      ];
    };

    services.printing = {
      enable = true;
      browsed.enable = false;
      listenAddresses = [ "127.0.0.1:631" ];
      drivers = [ pkgs.epson-escpr2 ];
    };

    hardware.printers = {
      ensureDefaultPrinter = "ET-3750";
      ensurePrinters = [
        {
          name = "ET-3750";
          location = "Office";
          description = "Epson ET-3750";
          deviceUri = "https://drucker:631/ipp/print";
          model = "epson-inkjet-printer-escpr2/Epson-ET-3750_Series-epson-escpr2-en.ppd";
        }
      ];
    };

    environment.systemPackages = with pkgs.kdePackages; [
      print-manager
      skanlite
    ];
  };
}
