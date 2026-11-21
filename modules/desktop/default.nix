{
  config,
  lib,
  pkgs,
  options,
  ...
}:
{
  imports = [
    ./audio.nix
    ./browser.nix
    ./coding.nix
    ./fonts.nix
    ./networking.nix
    ./gaming.nix
    ./printer.nix
  ];

  options.includes.desktop.enable = lib.mkEnableOption "Enables desktop networking";

  config = lib.mkIf (config.includes.desktop.enable) (
    lib.mkMerge [
      {
        nixpkgs.config.rocmSupport = true;

        includes.desktop = {
          audio.enable = lib.mkDefault true;
          coding.enable = lib.mkDefault true;
          networking.enable = lib.mkDefault true;
          fonts.enable = lib.mkDefault true;
          gaming.enable = lib.mkDefault true;
          printer.enable = lib.mkDefault true;
        };

        services = {
          acpid.enable = true;
          avahi = {
            enable = true;
            openFirewall = true;
            nssmdns4 = true;
          };
          desktopManager.plasma6.enable = true;
          displayManager.plasma-login-manager = {
            enable = true;
            settings = {
              General = {
                Numlock = true;
              };
            };
          };
          speechd.enable = false;
          orca.enable = false;
          fwupd.enable = false;
        };

        systemd.defaultUnit = "graphical.target";

        hardware = {
          bluetooth = {
            enable = true;
            package = pkgs.bluez5-experimental;
            settings.General.Experimental = true;
            input.General.ClassicBondedOnly = false;
          };
          graphics = {
            enable = true;
            enable32Bit = true;
            extraPackages = [ pkgs.libva ];
            extraPackages32 = [ pkgs.pkgsi686Linux.libva ];
          };
        };
        xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
        environment = {
          sessionVariables = {
            AMD_VULKAN_ICD = "RADV";
            NIXOS_OZONE_WL = "1";
            QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
            _JAVA_AWT_WM_NONREPARENTING = "1";
            GTK_USE_PORTAL = "1";
          };
          systemPackages = [
            pkgs.btop-rocm
          ]
          ++ (with pkgs.kdePackages; [
            ark
            kate
            kalk
            kleopatra
            kzones
          ]);

          plasma6.excludePackages = with pkgs.kdePackages; [
            elisa
            khelpcenter
            kate
            gwenview
          ];
        };
        programs = {
          kde-pim = {
            enable = true;
            kmail = true;
          };
          neovim.waylandSupport = true;
        };
      }
      (lib.optionalAttrs (options ? home-manager) {
        nixpkgs.config.allowUnfreePackages = [
          "discord"
          "discord-unwrapped"
        ];
        home-manager.sharedModules = [
          ({ pkgs, ... }: {
            services.nextcloud-client = {
              enable = true;
              startInBackground = true;
            };
            home.packages = with pkgs; [
              kdePackages.plasma-integration
              haruna
              libreoffice-qt
              cifs-utils
              discord
            ];
          })
        ];
      })
    ]
  );
}
