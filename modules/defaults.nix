{
  config,
  lib,
  pkgs,
  sources,
  options,
  ...
}:
let
  inherit (builtins) substring hashString;
  _1GB = 1024 * 1024 * 1024;
in
lib.mkMerge [
  {
    sops = {
      secrets = {
        nix-gh-token-ro.sopsFile = ./secrets.yaml;
        nix-netrc-ro.sopsFile = ./secrets.yaml;
      };
      templates = {
        nix-gh-token-ro = {
          content = ''
            extra-access-tokens = github.com=${config.sops.placeholder.nix-gh-token-ro}
          '';
          group = config.users.groups.nixbld.name;
          mode = "0440";
        };
        nix-netrc-ro = {
          content = ''
            machine cache.pointjig.de
            password ${config.sops.placeholder.nix-netrc-ro}
          '';
          group = config.users.groups.nixbld.name;
          mode = "0440";
        };
      };
    };

    networking.hostId = substring 0 8 (hashString "md5" "${config.networking.hostName}");
    environment.defaultPackages = lib.mkForce [ ];
    boot = {
      bcache.enable = false;
      enableContainers = lib.mkDefault false;
      tmp = {
        useTmpfs = lib.mkDefault true;
        cleanOnBoot = true;
      };
      swraid.enable = lib.mkDefault false;
    };
    time.timeZone = "Europe/Berlin";
    i18n.defaultLocale = "de_DE.UTF-8";
    console = {
      earlySetup = true;
      font = "Lat2-Terminus16";
      keyMap = "de";
    };
    documentation = {
      enable = lib.mkDefault false;
      doc.enable = lib.mkDefault false;
      dev.enable = lib.mkDefault false;
      info.enable = lib.mkDefault false;
      nixos.enable = lib.mkDefault false;
      man.enable = lib.mkDefault false;
    };
    users = {
      mutableUsers = false;
      users.root.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMguHbKev03NMawY9MX6MEhRhd6+h2a/aPIOorgfB5oM"
      ];
    };
    services = {
      openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
        };
      };
      lvm.enable = false;
      journald.settings.Journal = {
        SystemMaxUse = lib.mkDefault "75M";
        SystemMaxFileSize = lib.mkDefault "25M";
      };
      dbus.implementation = lib.mkDefault "broker";
    };
    system = {
      stateVersion = lib.mkDefault "23.05";
      disableInstallerTools = lib.mkDefault true;
      configurationRevision =
        let
          gitRevision = fetchGit { url = ../..; };
        in
        gitRevision.rev or "dirty";
    };
    programs = {
      nh = {
        enable = true;
        clean = {
          enable = true;
          dates = "daily";
          extraArgs = lib.mkDefault "--keep 5 --keep-since 7d";
        };
      };
      nano.enable = false;
      neovim = {
        enable = true;
        defaultEditor = true;
        vimAlias = true;
        waylandSupport = lib.mkDefault false;
      };
    };
    nix = {
      channel.enable = false;
      package = lib.mkDefault pkgs.nix;
      nixPath = [
        "nixpkgs=${sources.nixpkgs}"
      ];
      settings = {
        auto-optimise-store = true;
        allow-import-from-derivation = false;
        substituters = [
          "https://cache.pointjig.de/nixos"
          "https://nix-community.cachix.org"
          "https://x86-64-v3.cachix.org"
        ];
        trusted-public-keys = [
          "nixos:m4zyjiPgXOAWJZ/qVawVuOvPCmrSOfagQc/zbaDmq2Q="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "x86-64-v3.cachix.org-1:lNFBQzBpuTi7qkeUySCuAYnTZHSbwKYAgTLR7pYyZGU="
        ];
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        cores = lib.mkDefault 4;
        max-jobs = lib.mkDefault 1;
        netrc-file = config.sops.templates.nix-netrc-ro.path;
        min-free = toString (1 * _1GB);
        max-free = toString (5 * _1GB);
      };
      extraOptions = ''
        !include ${config.sops.templates.nix-gh-token-ro.path}
      '';
      nrBuildUsers = 8;
      daemonIOSchedClass = "idle";
      daemonCPUSchedPolicy = "idle";
    };
  }
  (lib.optionalAttrs (options ? home-manager) {
    home-manager.sharedModules = [
      ({ config, ... }: {
        imports = [ "${sources.sops-nix}/modules/home-manager/sops.nix" ];

        sops = {
          age.keyFile = "${config.xdg.configHome}/sops/age/keys.txt";
          defaultSymlinkPath = "/run/user/${toString config.home.uid}/secrets";
          defaultSecretsMountPoint = "/run/user/${toString config.home.uid}/secrets.d";
        };
        home.stateVersion = "23.05";
        manual.manpages.enable = lib.mkDefault false;
        programs.man.enable = lib.mkDefault false;
      })
    ];
  })
]
