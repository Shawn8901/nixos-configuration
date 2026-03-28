{
  den,
  inputs,
  lib,
  ...
}:
{

  flake-file.inputs = {
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence = {
      url = "github:nix-community/impermanence";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  den.ctx.user.includes = [ den.provides.mutual-provider ];
  den.schema.user.classes = lib.mkDefault [ "homeManager" ];

  den.ctx.hm-host.nixos.home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
  };

  den.default = {
    includes = [
      den.provides.inputs'
      den.provides.self'
      den.provides.define-user

      den.provides.hostname
      (den.lib.parametric.exactly {
        includes = [
          (
            { host }:
            {
              ${host.class}.networking.hostId = builtins.substring 0 8 (
                builtins.hashString "md5" "${host.hostName}"
              );
            }
          )
        ];
      })
    ];

    nixos =
      {
        lib,
        pkgs,
        config,
        ...
      }:
      {
        imports = [
          inputs.sops-nix.nixosModules.default
          inputs.impermanence.nixosModules.impermanence
        ];

        sops = {
          secrets = {
            nix-gh-token-ro = {
              sopsFile = ./secrets.yaml;
              group = config.users.groups.nixbld.name;
              mode = "0444";
            };
            nix-netrc-ro = {
              sopsFile = ./secrets.yaml;
            };
          };
          templates = {
            nix-gh-token-ro = {
              content = ''
                extra-access-tokens = github.com=${config.sops.placeholder.nix-gh-token-ro}
              '';
              group = config.users.groups.nixbld.name;
              mode = "0444";
            };
            nix-netrc-ro = {
              content = ''
                machine cache.pointjig.de
                password ${config.sops.placeholder.nix-netrc-ro}
              '';
              group = config.users.groups.nixbld.name;
              mode = "0444";
            };
          };
        };

        boot = {
          bcache.enable = false;
          enableContainers = false;
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
        programs.command-not-found.enable = false;

        environment = {
          systemPackages = [ pkgs.vim ];
          defaultPackages = lib.mkForce [ ];
        };

        system = {
          stateVersion = "23.05";
          disableInstallerTools = true;
        };
        documentation = {
          enable = lib.mkDefault false;
          doc.enable = lib.mkDefault false;
          dev.enable = lib.mkDefault false;
          info.enable = lib.mkDefault false;
          nixos.enable = lib.mkDefault false;
          man.enable = lib.mkDefault false;
        };

        nix = {
          channel.enable = false;
          package = pkgs.nix;
          settings = {
            auto-optimise-store = true;
            allow-import-from-derivation = false;
            substituters = [
              "https://cache.pointjig.de/nixos"
              "https://nix-community.cachix.org"
            ];
            trusted-public-keys = [
              "nixos:m4zyjiPgXOAWJZ/qVawVuOvPCmrSOfagQc/zbaDmq2Q="
              "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            ];
            cores = lib.mkDefault 4;
            max-jobs = lib.mkDefault 1;
            experimental-features = [
              "nix-command"
              "flakes"
            ];
            netrc-file = config.sops.templates.nix-netrc-ro.path;
          };
          extraOptions = ''
            !include ${config.sops.templates.nix-gh-token-ro.path}
            min-free = ${toString (1024 * 1024 * 1024)}
            max-free = ${toString (5 * 1024 * 1024 * 1024)}
          '';
          nrBuildUsers = 16;
          daemonIOSchedClass = "idle";
          daemonCPUSchedPolicy = "idle";
        };

        users.mutableUsers = false;
        services = {
          openssh = {
            enable = true;
            settings = {
              PasswordAuthentication = false;
              KbdInteractiveAuthentication = false;
            };
          };
          lvm.enable = false;
          journald.extraConfig = ''
            SystemMaxUse=75M
            SystemMaxFileSize=25M
          '';
          dbus.implementation = "broker";
        };
        programs.nh = {
          enable = true;
          flake = lib.mkDefault "github:shawn8901/nixos-configuration";
          clean = {
            enable = true;
            dates = "daily";
            extraArgs = lib.mkDefault "--keep 5 --keep-since 7d";
          };
        };
      };
    homeManager =
      {
        config,
        pkgs,
        lib,
        ...
      }:
      {
        imports = [
          inputs.sops-nix.homeManagerModule
        ];
        home.stateVersion = "23.05";
        sops = {
          age.keyFile = "${config.xdg.configHome}/sops/age/keys.txt";
          # defaultSymlinkPath = "/run/user/${toString user.uid}/secrets";
          # defaultSecretsMountPoint = "/run/user/${toString user.uid}/secrets.d";
        };

        manual.manpages.enable = lib.mkDefault false;
        programs = {
          man.enable = lib.mkDefault false;
          vim = {
            enable = true;
            defaultEditor = true;
            packageConfigurable = lib.mkDefault pkgs.vim;
            extraConfig = ''
              set nocompatible
              filetype indent on
              syntax on
              set hidden
              set wildmenu
              set showcmd
              set incsearch
              set hlsearch
              set backspace=indent,eol,start
              set autoindent
              set nostartofline
              set ruler
              set laststatus=2
              set confirm
              set visualbell
              set t_vb=
              set cmdheight=2
              set number
              set notimeout ttimeout ttimeoutlen=200
              set pastetoggle=<F11>
              set tabstop=8
              set shiftwidth=4
              set softtabstop=4
              set expandtab
              map Y y$
              nnoremap <C-L> :nohl<CR><C-L>
            '';
          };
        };
      };
  };
}
