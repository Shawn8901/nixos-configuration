# flake-file.inputs.asus-numberpad-driver = {
#   url = "github:shawn8901/asus-numberpad-driver/nixos_improvement";
#   inputs.nixpkgs.follows = "nixpkgs";
# };

{
  pkgs,
  lib,
  config,
  modulesPath,
  sources,
  ...
}:
{
  sops = {
    defaultSopsFile = ./secrets.yaml;
    secrets.zrepl = { };
  };

  includes = {
    monitoree.enable = true;
    desktop.enable = true;
    managed-users.enable = true;
    zfs.enable = true;
    zrepl.enable = true;
  };

  imports = [
    "${sources.asus-numberpad-driver}/nix/module.nix"
    "${modulesPath}/profiles/perlless.nix"
    "${sources.home-manager}/nixos"
    "${sources.preservation}/module.nix"
    ./preservation.nix
    "${sources.disko}/module.nix"
    ./disko-config.nix
    ./hardware.nix
  ];

  home-manager = {
    useUserPackages = true;
    useGlobalPkgs = true;
    extraSpecialArgs = {
      inherit sources;
    };
    users.shawn = { };
  };

  systemd = {
    services.display-manager.serviceConfig.KeyringMode = "inherit";
    tmpfiles.rules = [ "d /media/nas 0750 shawn users -" ];
  };

  environment.systemPackages = [ pkgs.zenmonitor ];

  services = {
    zfs.autoScrub.pools = [ "rpool" ];
    zrepl.settings.jobs = [
      {
        name = "zenbook";
        type = "push";
        filesystems."rpool/safe<" = true;
        snapshotting = {
          type = "periodic";
          interval = "1h";
          prefix = "zrepl_";
        };
        connect = {
          type = "tls";
          address = "tank.fritz.box:8888";
          ca = ../tank/zrepl.crt;
          cert = ./zrepl.crt;
          key = config.sops.secrets.zrepl.path;
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
    upower.enable = true;
  };
  hardware = {
    amdgpu.initrd.enable = true;
    keyboard.zsa.enable = true;
    asus-numberpad-driver = {
      enable = true;
      layout = "up5401ea";
      package = pkgs.callPackage "${sources.asus-numberpad-driver}/nix" { };
      defaultConfig = {
        main = {
          "activation_time" = "0.5";
          "multitouch" = "1";
          "default_backlight_level" = "0x01";
          "top_left_icon_brightness_func_max_min_only" = "1";
          "top_left_icon_activation_time" = "0.5";
          "top_left_icon_slide_func_activation_radius" = "1200";
          "top_left_icon_slide_func_activates_numpad" = "1";
        };
      };
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

  boot.zfs.useKeyringForCredentials = true;
  # };
}
