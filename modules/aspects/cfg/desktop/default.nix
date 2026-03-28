{
  den,
  cfg,
  ...
}:
{

  flake-file.inputs.firefox-addons.url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";

  cfg.desktop = {
    includes =
      (with cfg.desktop.provides; [
        audio
        browser
        coding
        fonts
        networking
      ])
      ++ [ (den.provides.unfree [ "discord" ]) ];

    nixos =
      { pkgs, ... }:
      {
        services = {
          acpid.enable = true;
          avahi = {
            enable = true;
            openFirewall = true;
            nssmdns4 = true;
          };
          desktopManager.plasma6.enable = true;
          displayManager.sddm = {
            enable = true;
            autoNumlock = true;
            wayland = {
              enable = true;
              compositor = "kwin";
            };
          };
          speechd.enable = false;
          orca.enable = false;
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
            #pkgs.btop-rocm
            pkgs.btop
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
            kwin-x11
          ];
        };
        programs.kde-pim = {
          enable = true;
          kmail = true;
        };
      };

    homeManager =
      {
        pkgs,
        ...
      }:
      {
        xdg = {
          enable = true;
          mime.enable = true;
          configFile = {
            "chromium-flags.conf".text = ''
              --ozone-platform-hint=auto
              --enable-features=WaylandWindowDecorations
            '';
          };
        };
        services = {
          nextcloud-client = {
            enable = true;
            startInBackground = true;
          };
          gpg-agent = {
            enable = true;
            pinentry.package = pkgs.pinentry-qt;
          };
        };

        home.packages = with pkgs; [
          vlc
          libreoffice-qt
          element-desktop
          cifs-utils
          (discord.override {
            nss = nss_latest;
          })
        ];

        programs.vim.packageConfigurable = pkgs.vim-full;
      };
  };
}
