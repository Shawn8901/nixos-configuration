{
  config,
  lib,
  pkgs,
  options,
  ...
}:
{
  options.includes.desktop.coding.enable = lib.mkEnableOption "Enables desktop coding";

  config = lib.mkIf (config.includes.desktop.coding.enable) (
    lib.mkMerge [
      ({
        programs = {
          ssh.startAgent = true;
        };

        # perlless module is loaded, mysql still has perl tooling
        system.forbiddenDependenciesRegexes = lib.mkForce [ ];
        services.mysql = {
          enable = false;
          package = pkgs.mariadb;
          ensureDatabases = [ "db" ];
          ensureUsers = [
            {
              name = "shawn";
              ensurePermissions = {
                "db.*" = "ALL PRIVILEGES";
              };
            }
          ];
        };
      })
      (lib.optionalAttrs (options ? home-manager) {
        nixpkgs.config.allowUnfreePackages = [
          "vscode"
          "vscode-extension-mhutchie-git-graph"
          "vscode-extension-MS-python-vscode-pylance"
          "vscode-extension-bmewburn-vscode-intelephense-client"
        ];

        home-manager.sharedModules = [
          ({ config, pkgs, ... }: {
            sops = {
              secrets.attic-token.sopsFile = ./secrets.yaml;
              templates."attic-config" = {
                content = ''
                  default-server = "nixos"
                  [servers.nixos]
                  endpoint = "https://cache.pointjig.de"
                  token = "${config.sops.placeholder.attic-token}"
                '';
                mode = "0600";
                path = "${config.xdg.configHome}/attic/config.toml";
              };
            };

            systemd.user.services.attic-watch-store = {
              Unit = {
                Description = "Upload all store content to binary catch";
              };
              Install = {
                WantedBy = [ "default.target" ];
              };
              Service = {
                ExecStart = "${lib.getExe pkgs.attic-client} watch-store nixos";
              };
            };

            home.packages = with pkgs; [
              attic-client
              sops
              nix-tree
              nixpkgs-review
              lon
            ];

            programs = {
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
                      "[javascript]" = {
                        "editor.defaultFormatter" = "dbaeumer.vscode-eslint";
                      };
                      "editor.tabSize" = 2;
                      "eslint.format.enable" = true;
                      "terminal.integrated.gpuAcceleration" = false;
                      "terminal.integrated.persistentSessionReviveProcess" = "never";
                      "terminal.integrated.enablePersistentSessions" = false;
                      "terminal.integrated.fontFamily" = "MesloLGS Nerd Font Mono";
                      "files.trimFinalNewlines" = true;
                      "files.insertFinalNewline" = true;
                      "diffEditor.ignoreTrimWhitespace" = false;
                      "editor.formatOnSave" = true;
                      "nix.enableLanguageServer" = true;
                      "nix.formatterPath" = "${lib.getExe pkgs.nixfmt}";
                      "nix.serverPath" = "${lib.getExe pkgs.nil}";
                      "nix.serverSettings" = {
                        "nil" = {
                          "diagnostics" = {
                            "ignored" = [ ];
                          };
                          "formatting" = {
                            "command" = [ "${lib.getExe pkgs.nixfmt}" ];
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
                      "json.schemaDownload.trustedDomains" = {
                        "https://developer.microsoft.com/json-schemas/" = true;
                        "https://json-schema.org/" = true;
                        "https://json.schemastore.org/" = true;
                        "https://opencode.ai/config.json" = true;
                        "https://raw.githubusercontent.com/devcontainers/spec/" = true;
                        "https://raw.githubusercontent.com/microsoft/vscode/" = true;
                        "https://schemastore.azurewebsites.net/" = true;
                        "https://spec.openapis.org/" = true;
                        "https://www.schemastore.org/" = true;
                        "https://models.dev/model-schema.json" = true;
                      };
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
                      jeff-hykin.better-nix-syntax

                      # php dev
                      bmewburn.vscode-intelephense-client

                      # js dev
                      dbaeumer.vscode-eslint

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

                      (pkgs.vscode-utils.buildVscodeMarketplaceExtension {
                        mktplcRef = {
                          name = "stnescript-support";
                          publisher = "STNE";
                          version = "1.0.5";
                          hash = "sha256-hSV8Iyi5MEofRzaIdjVcqK5CDMVrLbdfQW4m0SUjHNg=";
                        };
                      })
                    ];
                  };
                };
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
                signing.format = null;
                settings = {
                  user = {
                    name = "Shawn8901";
                    email = "shawn8901@googlemail.com";
                  };
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
                settings = {
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
                enableDefaultConfig = false;
              };
              zsh.siteFunctions.cherryPick = "gh pr diff --patch $1 | git am";
            };
            services = {
              ssh-agent.enable = true;
              gpg-agent = {
                enable = true;
                pinentry.package = pkgs.pinentry-qt;
              };
            };
          })
        ];
      })
    ]
  );
}
