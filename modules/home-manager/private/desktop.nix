{
  self',
  config,
  lib,
  pkgs,
  inputs,
  inputs',
  ...
}:
let
  inherit (lib) mkEnableOption mkIf getExe;
  inherit (inputs.firefox-addons.lib.${system}) buildFirefoxXpiAddon;
  inherit (pkgs.hostPlatform) system;

  cfg = config.shawn8901.desktop;
  firefox-addon-packages = inputs'.firefox-addons.packages;
in
{

  options = {
    shawn8901.desktop = {
      enable = mkEnableOption "my desktop settings for home manager";
    };
  };
  config = mkIf cfg.enable {

    sops.secrets.attic.path = "${config.xdg.configHome}/attic/config.toml";

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
    home.packages =
      with pkgs;
      [
        sops
        samba
        keepassxc
        (discord.override {
          nss = nss_latest;
        })
        vlc
        kdePackages.plasma-integration
        libreoffice-qt

        nix-tree
        nixpkgs-review
        vdhcoapp
        element-desktop
      ]
      ++ (with self'.packages; [
        nas
        generate-zrepl-ssl
      ]);
    programs = {
      man.enable = true;
      firefox = {
        enable = true;
        package = pkgs.firefox;
        nativeMessagingHosts = with pkgs; [
          vdhcoapp
          keepassxc
        ];
        profiles."shawn" = {
          extensions = {
            packages = with firefox-addon-packages; [
              ublock-origin
              umatrix
              plasma-integration
              h264ify
              bitwarden
              # firefox addons are from a input, that does not share pkgs with the host and some can not pass a
              # nixpkgs.config.allowUnfreePredicate to a flake input.
              # So overriding the stdenv is the only solution here to use the hosts nixpkgs.config.allowUnfreePredicate.
              (tampermonkey.override { inherit (pkgs) stdenv fetchurl; })
              (betterttv.override { inherit (pkgs) stdenv fetchurl; })
              # Download all plugins which are not in the repo manually
              (buildFirefoxXpiAddon {
                pname = "Video-DownloadHelper";
                version = "9.5.0.2";
                addonId = "{b9db16a4-6edc-47ec-a1f4-b86292ed211d}";
                url = "https://addons.mozilla.org/firefox/downloads/file/4502183/video_downloadhelper-9.5.0.2.xpi";
                sha256 = "sha256-wtzC+7WMWhwRXYMe0mlkQzz/pK3fjFJ7cLSF0f6Levs=";
                meta = { };
              })
            ];
          };
          settings = {
            "app.update.auto" = false;
            "browser.crashReports.unsubmittedCheck.enabled" = false;
            "browser.newtab.preload" = false;
            "browser.newtabpage.activity-stream.enabled" = false;
            "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
            "browser.newtabpage.activity-stream.telemetry" = false;
            "browser.ping-centre.telemetry" = false;
            "browser.safebrowsing.malware.enabled" = true;
            "browser.safebrowsing.phishing.enabled" = true;
            "browser.send_pings" = false;
            "browser.eme.ui.enabled" = true;
            "device.sensors.enabled" = false;
            "dom.battery.enabled" = false;
            "dom.webaudio.enabled" = false;
            "dom.private-attribution.submission.enabled" = false;
            "experiments.enabled" = false;
            "experiments.supported" = false;
            "privacy.donottrackheader.enabled" = true;
            "privacy.firstparty.isolate" = true;
            "privacy.trackingprotection.cryptomining.enabled" = true;
            "privacy.trackingprotection.enabled" = true;
            "privacy.trackingprotection.fingerprinting.enabled" = true;
            "privacy.trackingprotection.pbmode.enabled" = true;
            "privacy.trackingprotection.socialtracking.enabled" = true;
            "security.ssl.errorReporting.automatic" = false;
            "services.sync.engine.addons" = false;
            "services.sync.addons.ignoreUserEnabledChanges" = true;
            "toolkit.telemetry.archive.enabled" = false;
            "toolkit.telemetry.bhrPing.enabled" = false;
            "toolkit.telemetry.enabled" = false;
            "toolkit.telemetry.firstShutdownPing.enabled" = false;
            "toolkit.telemetry.hybridContent.enabled" = false;
            "toolkit.telemetry.newProfilePing.enabled" = false;
            "toolkit.telemetry.reportingpolicy.firstRun" = false;
            "toolkit.telemetry.server" = "";
            "toolkit.telemetry.shutdownPingSender.enabled" = false;
            "toolkit.telemetry.unified" = false;
            "toolkit.telemetry.updatePing.enabled" = false;
            "toolkit.telemetry.pioneer-new-studies-available" = false;
            "gfx.webrender.compositor.force-enabled" = true;
            "browser.cache.disk.enable" = false;
            "browser.cache.memory.enable" = true;
            "extensions.pocket.enabled" = false;
            "media.ffmpeg.vaapi.enabled" = true;
            "media.ffvpx.enabled" = false;
            "media.navigator.mediadatadecoder_vpx_enabled" = true;
            "media.rdd-vpx.enabled" = false;
            "media.gmp-widevinecdm.enabled" = true;
          };
        };
      };

      vscode = {
        enable = true;
        mutableExtensionsDir = false;
        package = pkgs.vscode;
        profiles = {
          default = {
            enableExtensionUpdateCheck = false;
            enableUpdateCheck = false;
            keybindings = [
              {
                "key" = "ctrl+d";
                "command" = "-editor.action.addSelectionToNextFindMatch";
                "when" = "editorFocus";
              }
              {
                "key" = "ctrl+d";
                "command" = "editor.action.deleteLines";
                "when" = "textInputFocus && !editorReadonly";
              }
              {
                "key" = "ctrl+shift+k";
                "command" = "-editor.action.deleteLines";
                "when" = "textInputFocus && !editorReadonly";
              }
              {
                "key" = "ctrl+shift+l";
                "command" = "find-it-faster.findWithinFiles";
              }
            ];
            userSettings = {
              "[nix]" = {
                "editor.insertSpaces" = true;
                "editor.tabSize" = 2;
                "editor.autoIndent" = "full";
                "editor.quickSuggestions" = {
                  "other" = true;
                  "comments" = false;
                  "strings" = true;
                };
                "editor.formatOnSave" = true;
                "editor.formatOnPaste" = true;
                "editor.formatOnType" = false;
              };
              "[rust]" = {
                "editor.defaultFormatter" = "rust-lang.rust-analyzer";
              };
              "[python]" = {
                "editor.formatOnSave" = true;
                "editor.formatOnPaste" = true;
                "editor.formatOnType" = false;
                "editor.defaultFormatter" = "ms-python.autopep8";
              };
              "[typescript]" = {
                "editor.defaultFormatter" = "esbenp.prettier-vscode";
              };
              "editor.tabSize" = 2;
              "terminal.integrated.gpuAcceleration" = false;
              "terminal.integrated.persistentSessionReviveProcess" = "never";
              "terminal.integrated.enablePersistentSessions" = false;
              "terminal.integrated.fontFamily" = "MesloLGS Nerd Font Mono";
              "files.trimFinalNewlines" = true;
              "files.insertFinalNewline" = true;
              "diffEditor.ignoreTrimWhitespace" = false;
              "editor.formatOnSave" = true;
              "nix.enableLanguageServer" = true;
              "nix.formatterPath" = "${getExe pkgs.nixfmt-rfc-style}";
              "nix.serverPath" = "${getExe pkgs.nil}";
              "nix.serverSettings" = {
                "nil" = {
                  "diagnostics" = {
                    "ignored" = [ ];
                  };
                  "formatting" = {
                    "command" = [ "${getExe pkgs.nixfmt-rfc-style}" ];
                  };
                  "flake" = {
                    "autoArchive" = true;
                    "autoEvalInputs" = true;
                  };
                };
              };
              "python.analysis.autoImportCompletions" = true;
              "python.analysis.typeCheckingMode" = "standard";
              "find-it-faster.general.useTerminalInEditor" = true;
            };
            extensions = with pkgs.vscode-extensions; [
              # general stuff
              mhutchie.git-graph
              editorconfig.editorconfig
              mkhl.direnv
              usernamehw.errorlens
              redhat.vscode-yaml

              # nix dev
              jnoortheen.nix-ide

              # python dev
              ms-python.python
              ms-python.vscode-pylance
              ms-python.debugpy
              ms-python.isort

              # typescript dev
              esbenp.prettier-vscode
              wix.vscode-import-cost

              # rust dev
              rust-lang.rust-analyzer
              vadimcn.vscode-lldb

              # go dev
              golang.go
            ];
          };
        };
      };

      vim = {
        enable = true;
        defaultEditor = true;
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

      direnv = {
        enable = true;
        nix-direnv.enable = true;
        enableZshIntegration = true;
        config = {
          "global" = {
            "warn_timeout" = "10s";
            "load_dotenv" = true;
          };
          "whitelist" = {
            prefix = [ "${config.home.homeDirectory}/dev" ];
          };
        };
      };

      git = {
        enable = true;
        userName = "Shawn8901";
        userEmail = "shawn8901@googlemail.com";
        extraConfig = {
          init.defaultBranch = "main";
          push.autoSetupRemote = "true";
          core.pager = "${pkgs.delta}/bin/delta";
          interactive.diffFilter = "${pkgs.delta}/bin/delta --color-only";
          merge.conflictStyle = "zdiff3";
          delta = {
            navigate = true;
            features = "side-by-side line-numbers decorations";
          };
        };
      };

      gh = {
        enable = true;
        extensions = [ pkgs.gh-poi ];
      };
      ssh = {
        enable = true;
        matchBlocks = {
          tank = {
            hostname = "tank";
            user = "shawn";
          };
          shelter = {
            hostname = "shelter.pointjig.de";
            port = 2242;
            user = "shawn";
          };
          watchtower = {
            hostname = "watchtower.pointjig.de";
            port = 2242;
            user = "shawn";
          };
          sap = {
            hostname = "clansap.org";
            user = "root";
          };
          next = {
            hostname = "next.clansap.org";
            port = 2242;
            user = "root";
          };
          pointjig = {
            hostname = "pointjig.de";
            port = 2242;
            user = "shawn";
          };
          sapsrv01 = {
            hostname = "sapsrv01.clansap.org";
            user = "root";
          };
          sapsrv02 = {
            hostname = "sapsrv02.clansap.org";
            user = "root";
          };
        };
      };
    };
  };
}
