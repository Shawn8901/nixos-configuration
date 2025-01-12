{
  pkgs,
  lib,
  config,
  self',
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.shawn8901.desktop;
in
{

  options = {
    shawn8901.desktop = {
      enable = mkEnableOption "my desktop settings for nixos";
    };
  };
  config = mkIf cfg.enable {

    documentation.man = {
      enable = lib.mkDefault true;
      generateCaches = lib.mkDefault true;
    };

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
      packages =
        [ pkgs.noto-fonts ]
        ++ (with pkgs.nerd-fonts; [
          noto
          liberation
          meslo-lg
          liberation
        ]);

    };

    services = {
      acpid.enable = true;
      avahi = {
        enable = true;
        openFirewall = true;
        nssmdns4 = true;
      };
      pipewire = {
        enable = true;
        pulse.enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        wireplumber.enable = true;
      };
      desktopManager.plasma6.enable = true;
      displayManager.sddm = {
        enable = lib.mkDefault true;
        autoNumlock = true;
        wayland = {
          enable = true;
          compositor = "kwin";
        };
      };
      speechd.enable = false;
      orca.enable = false;
    };

    security = {
      rtkit.enable = true;
      auditd.enable = false;
      audit.enable = false;
    };

    systemd.defaultUnit = "graphical.target";

    hardware = {
      bluetooth = {
        enable = true;
        package = pkgs.bluez5-experimental;
        settings.General.Experimental = true;
        input.General.ClassicBondedOnly = false;
      };
      pulseaudio.enable = false;
      graphics = {
        enable = true;
        enable32Bit = true;
        package = self'.packages.mesa_x86_64_v3.drivers;
        package32 = self'.packages.i686-mesa_x86_64_v3.drivers;
        extraPackages = [ pkgs.libva ];
        extraPackages32 = [ pkgs.pkgsi686Linux.libva ];
      };
    };
    xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    environment = {
      sessionVariables = {
        AMD_VULKAN_ICD = "RADV";
        MOZ_ENABLE_WAYLAND = "1";
        NIXOS_OZONE_WL = "1";
        QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
        _JAVA_AWT_WM_NONREPARENTING = "1";
        GTK_USE_PORTAL = "1";
      };
      systemPackages =
        [
          pkgs.git
          #pkgs.btop-rocm
          pkgs.btop
        ]
        ++ (with pkgs.kdePackages; [
          ark
          print-manager
          kate
          skanlite
          kalk
          kleopatra
        ]);

      plasma6.excludePackages = with pkgs.kdePackages; [
        elisa
        khelpcenter
        kate
        gwenview
      ];
    };

    programs = {
      dconf.enable = true;
      ssh.startAgent = true;
      steam = {
        enable = true;
        extraCompatPackages = [ pkgs.proton-ge-bin ];
        package = pkgs.steam-small.override {
          extraEnv = {
            inherit (config.environment.sessionVariables) AMD_VULKAN_ICD;
            extraBwrapArgs = [ "--unsetenv TZ" ];
          };
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
      kde-pim = {
        enable = true;
        kmail = true;
      };
    };

    nixpkgs.config.packageOverrides = pkgs: {
      udisks2 = pkgs.udisks2.override {
        btrfs-progs = null;
        nilfs-utils = null;
        xfsprogs = null;
        f2fs-tools = null;
      };

      kdePackages = pkgs.kdePackages.overrideScope (
        self: super: {
          akonadi = super.akonadi.override {
            withMariaDB = false;
            withSQLite = true;
            defaultBackend = "SQLITE";
          };
        }
      );
    };
  };
}
