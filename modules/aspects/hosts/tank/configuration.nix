{
  cfg,
  inputs,
  self,
  ...
}:
{

  flake-file.inputs.openarchiver = {
    url = "github:shawn8901/openarchiver-flake";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.aspects.tank = {
    includes = [
      cfg.monitoree
      cfg.nextcloud
      cfg.remote-builder
      cfg.server
      cfg.postgresql
      cfg.zfs
      cfg.zrepl
    ];
    nixos =
      {
        config,
        pkgs,
        lib,
        modulesPath,
        ...
      }:
      let
        inherit (config.sops) secrets;
        immichName = "immich.tank.pointjig.de";
      in
      {

        imports = [
          "${modulesPath}/profiles/perlless.nix"
          inputs.openarchiver.nixosModules.openarchiver
        ];
        # We dont build fully perlless yet
        system.forbiddenDependenciesRegexes = lib.mkForce [ ];

        sops = {
          defaultSopsFile = ./secrets.yaml;
          secrets = lib.mkMerge [
            {
              srv-ssh = { };
              zfs-ztank-key = {
                # Hack to have the zfs key material available very early for mounting
                neededForUsers = true;
              };
              zrepl = { };
              ela.neededForUsers = true;
              prometheus-fritzbox = {
                owner = config.services.prometheus.exporters.fritz.user;
                inherit (config.services.prometheus.exporters.fritz) group;
              };
              openarchiver = { };
            }
            (lib.optionalAttrs config.services.stalwart.enable {
              stalwart-fallback-admin = {
                owner = config.systemd.services.stalwart.serviceConfig.User;
              };
            })
          ];
        };

        networking = {
          firewall.allowedTCPPorts = [
            # Mail ports for stalwart
            25
            587
            993
            4190
          ];
          hosts = {
            "127.0.0.1" = lib.attrNames config.services.nginx.virtualHosts;
            "::1" = lib.attrNames config.services.nginx.virtualHosts;
          };
        };

        systemd = {
          network = {
            enable = true;
            networks."20-wired" = {
              matchConfig.Name = "eno1";
              networkConfig.DHCP = "yes";
              networkConfig.Domains = "fritz.box ~box ~.";
            };
            wait-online.ignoredInterfaces = [ "enp4s0" ];
          };
          services.prometheus-fritz-exporter = {
            requires = [ "network-online.target" ];
            after = [ "network-online.target" ];
          };
        };

        programs.ssh = {
          knownHosts = {
            sapsrv01 = {
              hostNames = [ "sapsrv01.clansap.org" ];
              publicKey = " ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFkeXDm5GJlVdQBM8Jh43JYi0X0Nf+idqnL4I4Kl1fbF";
            };
            sapsrv02 = {
              hostNames = [ "sapsrv02.clansap.org" ];
              publicKey = " ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJdBgG0egUCjainz/4p2f7txbzUeLvtItCowCb2vsZqB";
            };
          };
        };

        nix.settings = {
          keep-outputs = true;
          keep-derivations = true;
        };
        services = {
          immich = {
            enable = true;
            database.enable = true;
            settings = {
              server.externalDomain = "https://${immichName}";
              notifications.smtp.enabled = false;
              newVersionCheck.enabled = false;
              metadata.faces.import = false;
              ffmpeg = {
                threads = 2;
                acceptedVideoCodecs = [
                  "h264"
                  "hevc"
                  "vp9"
                  "av1"
                ];
                transcode = "required";
              };
            };
          };
          openssh = {
            ports = lib.mkForce [ 22 ];
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
              pools = [
                "rpool"
                "ztank"
              ];
            };
          };
          zrepl = {
            enable = true;
            package = pkgs.zrepl;
            settings.jobs = [
              {
                name = "rpool_safe";
                type = "snap";
                filesystems = {
                  "rpool/safe<" = true;
                };
                snapshotting = {
                  type = "periodic";
                  interval = "1h";
                  prefix = "zrepl_";
                };
                pruning = {
                  keep = [
                    {
                      type = "grid";
                      grid = "1x3h(keep=all) | 2x6h | 14x1d";
                      regex = "^zrepl_.*";
                    }
                    {
                      type = "regex";
                      negate = true;
                      regex = "^zrepl_.*";
                    }
                  ];
                };
              }
              {
                name = "pointalpha";
                type = "pull";
                root_fs = "ztank/backup/pointalpha";
                interval = "1h";
                connect = {
                  type = "tls";
                  address = "pointalpha:8888";
                  ca = self.outPath + "/files/certs/zrepl/pointalpha.crt";
                  cert = self.outPath + "/files/certs/zrepl/tank.crt";
                  key = secrets.zrepl.path;
                  server_cn = "pointalpha";
                };
                recv.placeholder.encryption = "inherit";
                pruning = {
                  keep_sender = [
                    { type = "not_replicated"; }
                    {
                      type = "grid";
                      grid = "3x1d";
                      regex = "^zrepl_.*";
                    }
                  ];
                  keep_receiver = [
                    {
                      type = "grid";
                      grid = "7x1d(keep=all) | 3x30d";
                      regex = "^zrepl_.*";
                    }
                  ];
                };
              }
              {
                name = "zenbook_sink";
                type = "sink";
                root_fs = "ztank/backup/zenbook";
                serve = {
                  type = "tls";
                  listen = ":8888";
                  ca = self.outPath + "/files/certs/zrepl/zenbook.crt";
                  cert = self.outPath + "/files/certs/zrepl/tank.crt";
                  key = secrets.zrepl.path;
                  client_cns = [ "zenbook" ];
                };
                recv.placeholder.encryption = "inherit";
              }
              {
                name = "sapsrv01";
                type = "pull";
                root_fs = "ztank/backup/sapsrv01";
                interval = "1h";
                connect = {
                  type = "ssh+stdinserver";
                  host = "sapsrv01.clansap.org";
                  port = 22;
                  user = "root";
                  identity_file = secrets.srv-ssh.path;
                  options = [ "Compression=yes" ];
                };
                recv.placeholder.encryption = "inherit";
                pruning = {
                  keep_receiver = [
                    {
                      type = "grid";
                      grid = "7x1d(keep=all) | 3x30d";
                      regex = "^auto_daily.*";
                    }
                  ];
                  keep_sender = [
                    {
                      type = "last_n";
                      count = 10;
                      regex = "^auto_daily.*";
                    }
                  ];
                };
              }
              {
                name = "sapsrv02";
                type = "pull";
                root_fs = "ztank/backup/sapsrv02";
                interval = "1h";
                connect = {
                  type = "ssh+stdinserver";
                  host = "sapsrv02.clansap.org";
                  port = 22;
                  user = "root";
                  identity_file = secrets.srv-ssh.path;
                  options = [ "Compression=yes" ];
                };
                recv.placeholder.encryption = "inherit";
                pruning = {
                  keep_receiver = [
                    {
                      type = "grid";
                      grid = "7x1d(keep=all) | 3x30d";
                      regex = "^auto_daily.*";
                    }
                  ];
                  keep_sender = [
                    {
                      type = "last_n";
                      count = 10;
                      regex = "^auto_daily.*";
                    }
                  ];
                };
              }
              {
                name = "tank_data";
                type = "snap";
                filesystems."ztank/data<" = true;
                snapshotting = {
                  type = "periodic";
                  interval = "1h";
                  prefix = "zrepl_";
                };
                pruning = {
                  keep = [
                    {
                      type = "grid";
                      grid = "1x3h(keep=all) | 2x6h | 7x1d | 1x30d | 1x365d";
                      regex = "^zrepl_.*";
                    }
                    {
                      type = "regex";
                      negate = true;
                      regex = "^zrepl_.*";
                    }
                  ];
                };
              }
              {
                name = "tank_replica";
                type = "push";
                filesystems."ztank/replica<" = true;
                snapshotting = {
                  type = "periodic";
                  interval = "1h";
                  prefix = "zrepl_";
                };
                connect = {
                  type = "tls";
                  address = "shelter.pointjig.de:8888";
                  ca = self.outPath + "/files/certs/zrepl/shelter.crt";
                  cert = self.outPath + "/files/certs/zrepl/tank.crt";
                  key = secrets.zrepl.path;
                  server_cn = "shelter";
                };
                send = {
                  encrypted = true;
                  compressed = true;
                };
                pruning = {
                  keep_sender = [
                    { type = "not_replicated"; }
                    {
                      type = "last_n";
                      count = 10;
                    }
                    {
                      type = "grid";
                      grid = "1x3h(keep=all) | 2x6h | 30x1d | 6x30d | 1x365d";
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
          avahi = {
            enable = true;
            nssmdns4 = true;
            openFirewall = true;
          };
          samba = {
            enable = true;
            nmbd.enable = false;
            openFirewall = true;
            settings = {
              global = {
                "logging" = "systemd";
                "min receivefile size" = 16384;
                "use sendfile" = true;
                "aio read size" = 16384;
                "aio write size" = 16384;
              };
              homes = {
                browseable = "no";
                writable = "no";
              };
              joerg = {
                path = "/media/joerg";
                "valid users" = "shawn";
                public = "no";
                writeable = "yes";
                printable = "no";
                "create mask" = 700;
                "directory mask" = 700;
                browseable = "yes";
              };
              ela = {
                path = "/media/daniela";
                "valid users" = "ela";
                public = "no";
                writeable = "yes";
                printable = "no";
                "create mask" = 700;
                "directory mask" = 700;
                browseable = "yes";
              };
              hopfelde = {
                path = "/media/hopfelde";
                public = "yes";
                writeable = "yes";
                printable = "no";
                browseable = "yes";
                available = "yes";
                "guest ok" = "yes";
                "valid users" = "nologin";
                "create mask" = 700;
                "directory mask" = 700;
              };
            };
          };
          smartd = {
            enable = true;
            devices = [
              { device = "/dev/nvme0"; }
              { device = "/dev/sda"; }
              { device = "/dev/sdb"; }
              { device = "/dev/sdc"; }
              { device = "/dev/sdb"; }
              { device = "/dev/sde"; }
              { device = "/dev/sdf"; }
            ];
          };
          nextcloud = {
            recommendedDefaults = true;
            configureMemories = true;
            configureMemoriesVaapi = true;
            configurePreviewSettings = true;
            hostName = "next.tank.pointjig.de";
            home = "/persist/var/lib/nextcloud";
            package = pkgs.nextcloud32;
            imaginary.enable = true;
            extraApps = {
              inherit (config.services.nextcloud.package.packages.apps) recognize;
            };
          };
        };

        users.users = lib.mkMerge [
          {
            ela = {
              hashedPasswordFile = secrets.ela.path;
              isNormalUser = true;
              group = "users";
              uid = 1001;
              shell = pkgs.zsh;
            };
            nologin = {
              isNormalUser = false;
              isSystemUser = true;
              group = "users";
            };
            shawn.extraGroups = [ "nextcloud" ];
          }
          (lib.optionalAttrs config.services.stalwart.enable {
            stalwart.extraGroups = [ "nginx" ];
          })
        ];

        services = {
          prometheus.exporters.fritz = {
            enable = true;
            listenAddress = "127.0.0.1";
            settings.devices = [
              {
                username = "prometheus";
                password_file = secrets.prometheus-fritzbox.path;
              }
            ];
          };
          vmagent.prometheusConfig.scrape_configs = [
            {
              job_name = "fritzbox-exporter";
              static_configs = [
                {
                  targets =
                    let
                      cfg = config.services.prometheus.exporters.fritz;
                    in
                    [ "${cfg.listenAddress}:${toString cfg.port}" ];
                }
              ];
            }
          ];
          nginx = {
            package = pkgs.nginx;
            virtualHosts = {
              "mail.tank.pointjig.de" = {
                serverName = "mail.tank.pointjig.de";
                forceSSL = true;
                enableACME = true;
                http3 = true;
                kTLS = true;
                locations = {
                  "/" = {
                    proxyPass = "http://localhost:8080";
                    recommendedProxySettings = true;
                  };
                };
              };
              "${immichName}" = {
                serverName = immichName;
                forceSSL = true;
                enableACME = true;
                http3 = true;
                kTLS = true;
                locations = {
                  "/" = {
                    proxyPass = "http://localhost:${toString config.services.immich.port}";
                    recommendedProxySettings = true;
                    proxyWebsockets = true;
                  };
                };
              };
            };
          };
          postgresql = {
            package = pkgs.postgresql_17;
            dataDir = "/persist/var/lib/postgresql/17";
            ensureDatabases = [
              "stalwart"
            ];
            ensureUsers = [
              {
                name = "stalwart";
                ensureDBOwnership = true;
              }
            ];
          };
          stalwart = {
            enable = true;
            stateVersion = "26.05";
            settings = {
              store.db = {
                type = "postgresql";
                host = "localhost";
                password = "%{env:POSTGRESQL_PASSWORD}%";
                port = 5432;
                database = "stalwart";
              };
              authentication.fallback-admin = {
                user = "admin";
                secret = "%{env:FALLBACK_ADMIN_PASSWORD}%";
              };
              lookup.default.hostname = "tank.pointjig.de";
              tracer.stdout = {
                level = "trace";
              };
              certificate.default = {
                private-key = "%{file:/var/lib/acme/tank.pointjig.de/key.pem}%";
                cert = "%{file:/var/lib/acme/tank.pointjig.de/cert.pem}%";
                default = true;
              };
              server = {
                http.use-x-forwarded = true;
                tls.enable = true;
                listener = {
                  "smtp" = {
                    bind = [ "[::]:25" ];
                    protocol = "smtp";
                  };
                  "submission" = {
                    bind = [ "[::]:587" ];
                    protocol = "smtp";
                  };
                  "imaptls" = {
                    bind = [ "[::]:993" ];
                    protocol = "imap";
                    tls.implicit = true;
                  };
                  "sieve" = {
                    bind = [ "[::]:4190" ];
                    protocol = "managesieve";
                  };
                  "http" = {
                    bind = [ "127.0.0.1:8080" ];
                    protocol = "http";
                  };
                };
              };
            };
          };
        };
        systemd.services.stalwart.serviceConfig = lib.mkIf config.services.stalwart.enable {
          EnvironmentFile = [ secrets.stalwart-fallback-admin.path ];
        };
        environment = {
          etc.".ztank_key".source = secrets.zfs-ztank-key.path;
          systemPackages =
            let
              extensions = config.services.postgresql.extensions;
              newPackage = pkgs.postgresql_17;
              newBin = "${if extensions == [ ] then newPackage else newPackage.withPackages extensions}/bin";
              oldPackage = config.services.postgresql.package;
              oldBin = "${if extensions == [ ] then oldPackage else oldPackage.withPackages extensions}/bin";
            in
            [
              (pkgs.writeShellScriptBin "pg_upgrade_version" ''
                set -eu

                BASE_DIR=''${1:-}

                # XXX replace `<new version>` with the psqlSchema here
                export NEWDATA="$BASE_DIR/var/lib/postgresql/${newPackage.psqlSchema}"

                # XXX specify the postgresql package you'd like to upgrade to

                export OLDDATA="$BASE_DIR/var/lib/postgresql/${oldPackage.psqlSchema}"

                echo "\$NEWDATA=$NEWDATA"
                echo "\$OLDDATA=$OLDDATA"

                [ ! -d "$OLDDATA" ] && echo "Old data dir for postgres does not exist" && exit 1

                read -p "Are you sure? " -n 1 -r
                echo ""
                if [[ $REPLY =~ ^[Yy]$ ]]
                then
                  install -d -m 0700 -o postgres -g postgres "$NEWDATA"
                  cd "$NEWDATA"
                  sudo -u postgres ${newBin}/initdb -D "$NEWDATA"

                  cp $OLDDATA/postgresql.conf $NEWDATA

                  sudo -u postgres ${newBin}/pg_upgrade \
                    --old-datadir "$OLDDATA" --new-datadir "$NEWDATA" \
                    --old-bindir ${oldBin} --new-bindir ${newBin}
                fi
              '')
            ];
        };

        services.openarchiver = {
          enable = true;
          configurePostgres = true;
          configureTika = true;
          configureMelisearch = true;
          configureRedis = true;
          environmentFile = secrets.openarchiver.path;
          settings = {
            ENABLE_DELETION = true;
          };
        };
      };
  };
}
