{
  self',
  self,
  pkgs,
  lib,
  config,
  flakeConfig,
  ...
}:
let
  fPkgs = self'.packages;
  hosts = self.nixosConfigurations;
  inherit (config.sops) secrets;

  allowUnfreePredicate = pkgs: (pkg: lib.elem (lib.getName pkg) pkgs);
in
{
  nixpkgs.config.allowUnfreePredicate = allowUnfreePredicate [
    "steam"
    "steam-run"
    "steam-original"
    "steam-unwrapped"
    "vscode"
    "vscode-extension-MS-python-vscode-pylance"
    "vscode-extension-mhutchie-git-graph"
    "discord"
    "teamspeak-client"
    "teamspeak3"
    "tampermonkey"
    "betterttv"
  ];

  sops.secrets = {
    zrepl.restartUnits = [ "zrepl.service" ];
    samba.sopsFile = ./../../files/secrets-desktop.yaml;
  };

  networking = {
    firewall = {
      logReversePathDrops = true;
      checkReversePath = false;
    };
    networkmanager = {
      enable = true;
      plugins = lib.mkForce [ ];
    };
    nftables.enable = true;
    hosts = {
      "192.168.11.31" = lib.attrNames hosts.tank.config.services.nginx.virtualHosts;
      "134.255.226.114" = [ "pointjig" ];
      "2a05:bec0:1:16::114" = [ "pointjig" ];
      "78.128.127.235" = [ "shelter" ];
      "2a01:8740:1:e4::2cd3" = [ "shelter" ];
    };
    dhcpcd.enable = false;
    useNetworkd = false;
    useDHCP = false;
  };
  systemd = {
    network.wait-online.anyInterface = true;
    services.display-manager.serviceConfig.KeyringMode = "inherit";
    tmpfiles.rules = [ "d /media/nas 0750 shawn users -" ];
  };

  environment.systemPackages = with pkgs; [
    cifs-utils
    zenmonitor
  ];

  services = {
    resolved.enable = false;
    udev.packages = [ pkgs.libmtp.out ];
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
        global.monitoring = [
          {
            type = "prometheus";
            listen = ":9811";
            listen_freebind = true;
          }
        ];
        jobs = [
          {
            name = "zenbook";
            type = "push";
            filesystems."rpool/safe<" = true;
            snapshotting = {
              type = "periodic";
              interval = "1h";
              prefix = "zrepl_";
            };
            connect =
              let
                zreplPort = flakeConfig.shawn8901.zrepl.servePorts hosts.tank.config.services.zrepl;
              in
              {
                type = "tls";
                address = "tank.fritz.box:${toString zreplPort}";
                ca = ../../files/public_certs/zrepl/tank.crt;
                cert = ../../files/public_certs/zrepl/zenbook.crt;
                key = secrets.zrepl.path;
                server_cn = "tank";
              };
            send = {
              encrypted = true;
              compressed = true;
            };
            pruning = {
              keep_sender = [
                { type = "not_replicated"; }
                {
                  type = "grid";
                  grid = "1x3h(keep=all) | 2x6h | 30x1d";
                  regex = "^zrepl_.*";
                }
                {
                  type = "regex";
                  negate = true;
                  regex = "^zrepl_.*";
                }
              ];
              keep_receiver = [
                {
                  type = "grid";
                  grid = "1x3h(keep=all) | 2x6h | 30x1d | 6x30d | 1x365d";
                  regex = "^zrepl_.*";
                }
              ];
            };
          }
        ];
      };
    };
    acpid.enable = true;
    upower.enable = true;
  };
  hardware = {
    amdgpu.initrd.enable = true;
    sane.enable = true;
    keyboard.zsa.enable = true;
    asus-touchpad-numpad = {
      enable = true;
      package = fPkgs.asus-touchpad-numpad-driver;
      model = "ux433fa";
    };
    asus.battery = {
      enable = true;
      chargeUpto = 80;
    };
  };

  programs.nh.flake = "/home/shawn/dev/nixos-configuration";

  environment = {
    etc."samba/credentials_shawn".source = secrets.samba.path;
    sessionVariables = {
      WINEFSYNC = "1";
      WINEDEBUG = "-all";
    };
  };

  users.users.shawn.extraGroups = [
    "video"
    "audio"
    "scanner"
    "lp"
    "networkmanager"
  ];

  security.pam.services.sddm-autologin.text = lib.mkForce ''
    auth     requisite pam_nologin.so
    auth     optional  ${config.systemd.package}/lib/security/pam_systemd_loadkey.so keyname=zfs-rpool
    auth     optional  ${pkgs.kdePackages.kwallet-pam}/lib/security/pam_kwallet5.so kwalletd=${pkgs.kdePackages.kwallet}/bin/kwalletd6
    auth     required  pam_succeed_if.so uid >= ${toString config.services.displayManager.sddm.autoLogin.minimumUid} quiet
    auth     required  pam_permit.so

    account  include   sddm

    password include   sddm

    session  include   sddm
  '';

  services.displayManager = {
    autoLogin = {
      enable = true;
      user = "shawn";
    };
    sessionData.autologinSession = "plasma";
  };
  boot.zfs.useKeyringForCredentials = true;

  shawn8901.desktop.enable = true;
}
