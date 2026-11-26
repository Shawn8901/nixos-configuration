{
  sources,
  config,
  pkgs,
  modulesPath,
  ...
}:
{

  imports = [
    ./hardware.nix
    "${sources.preservation}/module.nix"
    ./preservation.nix
    "${sources.home-manager}/nixos"
    "${modulesPath}/profiles/perlless.nix"
    "${sources.disko}/module.nix"
    ./disko-config.nix
    ./ai
  ];
  nixpkgs.config.allowUnfreePackages = [
    "keymapp"
    "makemkv"
  ];

  home-manager = {
    useUserPackages = true;
    useGlobalPkgs = true;
    extraSpecialArgs = {
      inherit sources;
    };
    users.shawn.imports = [ ./home.nix ];
  };

  includes = {
    desktop.enable = true;
    monitoree.enable = true;
    managed-users.enable = true;
    remote-builder = {
      enable = true;
      authorizationFile = config.sops.secrets.hydra-queue-runner-token.path;
    };
  };

  sops = {
    defaultSopsFile = ./secrets.yaml;
    secrets = {
      zrepl = { };
      hydra-queue-runner-token.owner = "hydra-builder";
    };
  };

  environment.systemPackages = [
    pkgs.solaar
    pkgs.android-tools
  ];
  nix.settings = {
    keep-outputs = true;
    keep-derivations = true;
    cores = 8;
    auto-allocate-uids = true;
    use-cgroups = true;
    system-features = [ "gccarch-x86-64-v3" ];
    experimental-features = [
      "auto-allocate-uids"
      "cgroups"
    ];
    extra-system-features = [
      "uid-range"
    ];
  };
  hardware.keyboard.zsa.enable = true;
  networking.hosts = {
    "192.168.11.31" = [
      "mail.tank.pointjig.de"
      "immich.tank.pointjig.de"
      "next.tank.pointjig.de"
    ];
  };

  services = {
    udev = {
      packages = [
        pkgs.libmtp.out
        pkgs.logitech-udev-rules
      ];
      extraRules = ''
        # Keymapp / Wally Flashing rules for the Moonlander and Planck EZ
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="df11", MODE:="0666", SYMLINK+="stm32_dfu"
        # Keymapp Flashing rules for the Voyager
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="3297", MODE:="0666", SYMLINK+="ignition_dfu"
      '';
    };
    smartd.devices = [ { device = "/dev/nvme1"; } ];
    pipewire.wireplumber.extraConfig = {
      "10-bluez"."monitor.bluez.properties" = {
        "bluez5.enable-sbc-xq" = true;
        "bluez5.enable-msbc" = true;
        "bluez5.enable-hw-volume" = true;
      };
      "11-bluetooth-policy"."wireplumber.settings"."bluetooth.autoswitch-to-headset-profile" = false;
    };
    zrepl.settings.jobs = [
      {
        name = "pointalpha_safe";
        type = "source";
        filesystems = {
          "rpool/safe<" = true;
        };
        snapshotting = {
          type = "periodic";
          interval = "1h";
          prefix = "zrepl_";
        };
        send = {
          encrypted = false;
          compressed = true;
        };
        serve = {
          type = "tls";
          listen = ":8888";
          ca = ../tank/zrepl.crt;
          cert = ./zrepl.crt;
          key = config.sops.secrets.zrepl.path;
          client_cns = [ "tank" ];
        };
      }
    ];
  };
  programs = {
    ausweisapp = {
      enable = true;
      openFirewall = true;
    };
    kdeconnect.enable = true;
    droidcam.enable = true;
  };
}
