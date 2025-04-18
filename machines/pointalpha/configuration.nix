{
  self,
  pkgs,
  lib,
  config,
  flakeConfig,
  modulesPath,
  ...
}:
let
  hosts = self.nixosConfigurations;

  inherit (config.sops) secrets;

  allowUnfreePredicate = pkgs: (pkg: lib.elem (lib.getName pkg) pkgs);

in
{

  imports = [ "${modulesPath}/profiles/perlless.nix" ];
  # We dont build fully perlless yet
  system.forbiddenDependenciesRegexes = lib.mkForce [ ];

  nixpkgs.config.allowUnfreePredicate = allowUnfreePredicate [
    "steam"
    "steam-run"
    "steam-original"
    "steam-unwrapped"
    "vscode"
    "vscode-extension-MS-python-vscode-pylance"
    "vscode-extension-mhutchie-git-graph"
    "deezer"
    "discord"
    "teamspeak-client"
    "teamspeak3"
    "tampermonkey"
    "betterttv"
    "teamviewer"
    "keymapp"
    "epsonscan2"
    "makemkv"
  ];

  sops.secrets = {
    zrepl = { };
    samba = { };
    samba-ela = { };
  };

  systemd.services.userborn.before = [ "systemd-oomd.socket" ];
  networking = {
    firewall.allowedTCPPorts = flakeConfig.shawn8901.zrepl.servePorts config.services.zrepl;
    networkmanager = {
      enable = true;
      plugins = lib.mkForce [ ];
    };
    nftables.enable = true;
    hosts."192.168.11.31" = lib.attrNames hosts.tank.config.services.nginx.virtualHosts;
    dhcpcd.enable = false;
    useNetworkd = false;
    useDHCP = false;
  };
  systemd = {
    tmpfiles.rules = [
      "d /media/nas 0750 shawn users -" # needed by own nas script for mounting
      "d /etc/exports.d 0750 root root" # needed by zfs to run 'zfs mount -a'
    ];
    network.wait-online.anyInterface = true;
  };

  services = {
    resolved.enable = false;
    udev.packages = [ pkgs.libmtp.out ];
    udev.extraRules = ''
      # Keymapp / Wally Flashing rules for the Moonlander and Planck EZ
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="df11", MODE:="0666", SYMLINK+="stm32_dfu"
      # Keymapp Flashing rules for the Voyager
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="3297", MODE:="0666", SYMLINK+="ignition_dfu"
    '';
    openssh = {
      enable = true;
      hostKeys = [
        {
          path = "/persist/etc/ssh/ssh_host_ed25519_key";
          type = "ed25519";
        }
        {
          path = "/persist/etc/ssh/ssh_host_rsa_key";
          type = "rsa";
          bits = 4096;
        }
      ];
    };
    zfs = {
      trim.enable = true;
      autoScrub = {
        enable = true;
        pools = [ "rpool" ];
      };
    };
    printing = {
      enable = true;
      browsed.enable = false;
      listenAddresses = [ "localhost:631" ];
      drivers = [ pkgs.epson-escpr2 ];
    };
    zrepl = {
      enable = true;
      package = pkgs.zrepl;
      settings = {
        global = {
          monitoring = [
            {
              type = "prometheus";
              listen = ":9811";
              listen_freebind = true;
            }
          ];
        };
        jobs = [
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
              ca = ../../files/public_certs/zrepl/tank.crt;
              cert = ../../files/public_certs/zrepl/pointalpha.crt;
              key = secrets.zrepl.path;
              client_cns = [ "tank" ];
            };
          }
        ];
      };
    };
    teamviewer.enable = false;
    smartd = {
      enable = true;
      devices = [ { device = "/dev/nvme1"; } ];
    };
    pipewire = {
      wireplumber.extraConfig = {
        "10-bluez" = {
          "monitor.bluez.properties" = {
            "bluez5.enable-sbc-xq" = true;
            "bluez5.enable-msbc" = true;
            "bluez5.enable-hw-volume" = true;
          };
          "11-bluetooth-policy" = {
            "wireplumber.settings" = {
              "bluetooth.autoswitch-to-headset-profile" = false;
            };
          };
          "92-low-latency" = {
            "context.properties" = {
              "default.clock.rate" = 48000;
              "default.clock.quantum" = 32;
              "default.clock.min-quantum" = 32;
              "default.clock.max-quantum" = 32;
            };
          };
        };
      };
      extraConfig.pipewire-pulse."92-low-latency" = {
        "context.properties" = [
          {
            name = "libpipewire-module-protocol-pulse";
            args = { };
          }
        ];
        "pulse.properties" = {
          "pulse.min.req" = "32/48000";
          "pulse.default.req" = "32/48000";
          "pulse.max.req" = "32/48000";
          "pulse.min.quantum" = "32/48000";
          "pulse.max.quantum" = "32/48000";
        };
        "stream.properties" = {
          "node.latency" = "32/48000";
          "resample.quality" = 1;
        };
      };
    };
  };

  hardware = {
    amdgpu.initrd.enable = true;
    sane = {
      enable = true;
      extraBackends = [
        (pkgs.epsonscan2.override {
          withNonFreePlugins = true;
          withGui = true;
        })
      ];
    };
    keyboard.zsa.enable = true;
  };

  programs = {
    ausweisapp = {
      enable = true;
      openFirewall = true;
    };
    nh.flake = "/home/shawn/dev/nixos-configuration";
    kdeconnect.enable = true;
  };

  virtualisation = {
    libvirtd = {
      enable = false;
      onBoot = "start";
      qemu.package = pkgs.qemu_kvm;
    };
  };

  nix.settings = {
    keep-outputs = true;
    keep-derivations = true;
    cores = 7;
  };
  environment = {
    systemPackages = [ pkgs.cifs-utils ];
    etc = {
      "samba/credentials_ela".source = secrets.samba-ela.path;
      "samba/credentials_shawn".source = secrets.samba.path;
    };
    sessionVariables = {
      WINEFSYNC = "1";
      WINEDEBUG = "-all";
    };
  };
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGsHm9iUQIJVi/l1FTCIFwGxYhCOv23rkux6pMStL49N"
  ];
  users.users.shawn.extraGroups = [
    "video"
    "audio"
    "scanner"
    "lp"
    "networkmanager"
  ];

  shawn8901.desktop.enable = true;

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
          backend = "postgres";
        };
      }
    );
  };
}
