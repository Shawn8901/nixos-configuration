{
  pkgs,
  lib,
  config,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    ;

  cfg = config.shawn8901.desktop;
in
{

  options = {
    shawn8901.desktop = {
      enable = mkEnableOption "my desktop settings for nixos";
    };
  };
  config = mkIf cfg.enable {
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
      # Upstream pipewire limits for realtime
      # https://gitlab.freedesktop.org/pipewire/pipewire/-/blob/master/meson_options.txt#L342
      pam.loginLimits = [
        {
          domain = "@users";
          item = "rtprio";
          type = "-";
          value = "95";
        }
        {
          domain = "@users";
          item = "memlock";
          type = "-";
          value = "4194304";
        }
        {
          domain = "@users";
          item = "nice";
          type = "-";
          value = "-19";
        }
      ];
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
      sessionVariables = lib.mkMerge [
        {
          AMD_VULKAN_ICD = "RADV";
          MOZ_ENABLE_WAYLAND = "1";
          NIXOS_OZONE_WL = "1";
          QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
          _JAVA_AWT_WM_NONREPARENTING = "1";
          GTK_USE_PORTAL = "1";
          PROTON_ENABLE_WAYLAND = "1";
        }
      ];
      systemPackages = [
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
        kzones
      ]);

      plasma6.excludePackages =
        with pkgs.kdePackages;
        [
          elisa
          khelpcenter
          kate
          gwenview
        ]
        ++ lib.optionals (!lib.versionOlder config.system.nixos.release "25.11") [
          pkgs.kdePackages.kwin-x11
        ];
    };

    boot.kernel.sysctl = {
      # https://github.com/ValveSoftware/Proton/wiki/Requirements#increasing-the-maximum-number-of-memory-map-areas-a-process-may-have
      "vm.max_map_count" = 2147483642;
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
    boot.kernelModules = (
      lib.optionals (lib.versionAtLeast config.boot.kernelPackages.kernel.version "6.15") [ "ntsync" ]
    );
  };
}
