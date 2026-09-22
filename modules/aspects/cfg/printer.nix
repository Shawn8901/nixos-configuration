{ den, ... }:
{
  cfg.printer = {

    includes = [
      (den.provides.unfree [ "epsonscan2" ])
    ];

    nixos =
      { pkgs, ... }:
      {
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
          listenAddresses = [ "localhost:631" ];
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
  };
}
