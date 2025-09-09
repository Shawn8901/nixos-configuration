{
  self',
  self,
  config,
  flakeConfig,
  pkgs,
  lib,
  modulesPath,
  ...
}:
let
  hosts = self.nixosConfigurations;
  fPkgs = self'.packages;

  inherit (config.sops) secrets;
  inherit (lib) concatStringsSep;

  immichName = "immich.tank.pointjig.de";
in
{

  imports = [ "${modulesPath}/profiles/perlless.nix" ];
  # We dont build fully perlless yet
  system.forbiddenDependenciesRegexes = lib.mkForce [ ];

  sops = {
    secrets = lib.mkMerge [
      {
        ssh-builder-key = {
          owner = "hydra-queue-runner";
        };
        srv-ssh = { };
        zfs-ztank-key = { };
        zrepl = { };
        ela = {
          neededForUsers = true;
        };
        nextcloud-admin = {
          owner = "nextcloud";
          group = "nextcloud";
        };
        prometheus-nextcloud = {
          owner = config.services.prometheus.exporters.nextcloud.user;
          inherit (config.services.prometheus.exporters.nextcloud) group;
        };
        prometheus-fritzbox = {
          owner = config.services.prometheus.exporters.fritz.user;
          inherit (config.services.prometheus.exporters.fritz) group;
        };
        # GitHub access token is stored on all systems with group right for nixbld
        # but hydra-queue-runner has to be able to read them but can not be added
        # to nixbld (it then crashes as soon as its writing to the store).
        nix-gh-token-ro.mode = lib.mkForce "0777";
        hydra-github-hook = { };
        hydra-github-auth = { };
        # mimir-env-dev = {
        #   file = ../../secrets/mimir-env-dev.age;
        #   owner = lib.mkIf config.services.stne-mimir.enable "mimir";
        #   group = lib.mkIf config.services.stne-mimir.enable "mimir";
        # };
        #  stfc-env-dev = {
        #   file = ../../secrets/stfc-env-dev.age;
        #   owner = lib.mkIf config.services.stfc-bot.enable "stfcbot";
        #   group = lib.mkIf config.services.stfc-bot.enable "stfcbot";
        # };
        cachix_token_file = { };
        cachix_signing_key = { };
      }
      (lib.optionalAttrs config.services.stalwart-mail.enable {
        stalwart-fallback-admin = {
          owner = config.systemd.services.stalwart-mail.serviceConfig.User;
        };
      })
    ];
    templates."hydra-write-token.conf" = {
      content = ''
        <github_authorization>
          Shawn8901 = Bearer ${config.sops.placeholder.hydra-github-auth}
        </github_authorization>
      '';
      owner = "hydra-queue-runner";
      group = "hydra";
      mode = "0660";
    };
    templates."hydra-hook-token.conf" = {
      content = ''
        <github>
          secret = ${config.sops.placeholder.hydra-github-hook}
        </github>
      '';
      owner = "hydra-www";
      group = "hydra";
      mode = "0660";
    };
  };

  networking = {
    firewall.allowedTCPPorts = (flakeConfig.shawn8901.zrepl.servePorts config.services.zrepl) ++ [
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
    services = {
      prometheus-fritz-exporter = {
        requires = [ "network-online.target" ];
        after = [ "network-online.target" ];
      };
      pointalpha-online =
        let
          systemFeatures = hosts.pointalpha.config.nix.settings.system-features;
          jobs = hosts.pointalpha.config.nix.settings.max-jobs;
          cores = hosts.pointalpha.config.nix.settings.cores;
        in
        {
          script = ''
            if ${pkgs.iputils}/bin/ping -c1 -w 1 pointalpha > /dev/null; then
              if ! grep pointalpha /tmp/hyda/dynamic-machines > /dev/null; then
                echo "ssh://root@pointalpha x86_64-linux,i686-linux ${secrets.ssh-builder-key.path} ${toString jobs} ${toString cores} ${concatStringsSep "," systemFeatures} - -" >  /tmp/hyda/dynamic-machines
                echo "Added pointalpha to dynamic build machines"
              fi
            else
              if grep pointalpha /tmp/hyda/dynamic-machines > /dev/null; then
                echo "" > /tmp/hyda/dynamic-machines
                echo "Cleared dynamic build machines"
              fi
            fi
          '';
        };
      userborn.before = [ "systemd-oomd.socket" ];
    };
    timers.pointalpha-online = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/1";
      };
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
      database = {
        enable = true;
        enableVectorChord = true;
        enableVectors = false;
      };
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
      settings = {
        global = {
          logging = [
            {
              type = "stdout";
              level = "warn";
              format = "human";
            }
          ];
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
              ca = ../../files/public_certs/zrepl/pointalpha.crt;
              cert = ../../files/public_certs/zrepl/tank.crt;
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
              ca = ../../files/public_certs/zrepl/zenbook.crt;
              cert = ../../files/public_certs/zrepl/tank.crt;
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
            connect =
              let
                zreplPort = flakeConfig.shawn8901.zrepl.servePorts hosts.shelter.config.services.zrepl;
              in
              {
                type = "tls";
                address = "shelter.pointjig.de:${toString zreplPort}";
                ca = ../../files/public_certs/zrepl/shelter.crt;
                cert = ../../files/public_certs/zrepl/tank.crt;
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
    };
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };
    samba = {
      enable = true;
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
      configureRecognize = true;
      settings.maintenance_window_start = "100";
    };
  };

  security = {
    auditd.enable = false;
    audit.enable = false;
  };
  users.users = lib.mkMerge [
    {
      root.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGsHm9iUQIJVi/l1FTCIFwGxYhCOv23rkux6pMStL49N"
      ];
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
      attic = {
        isNormalUser = false;
        isSystemUser = true;
        group = "users";
        home = "/var/lib/attic";
      };
    }
    (lib.optionalAttrs config.services.stalwart-mail.enable {
      stalwart-mail.extraGroups = [ "nginx" ];
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
      package = pkgs.nginxQuic;
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
      settings = {
        track_activities = true;
        track_counts = true;
        track_io_timing = true;
      };
      ensureDatabases = [
        "stalwart-mail"
      ];
      ensureUsers = [
        {
          name = "stalwart-mail";
          ensureDBOwnership = true;
        }
      ];
    };
    stalwart-mail = {
      enable = true;
      settings = {
        store.db = {
          type = "postgresql";
          host = "localhost";
          password = "%{env:POSTGRESQL_PASSWORD}%";
          port = 5432;
          database = "stalwart-mail";
        };
        storage.blob = "db";

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
  systemd.services.stalwart-mail.serviceConfig = lib.mkIf config.services.stalwart-mail.enable {
    EnvironmentFile = [ secrets.stalwart-fallback-admin.path ];
  };

  shawn8901 = {
    backup-rclone = {
      enable = true;
      sourceDir = "${config.services.nextcloud.home}/data/shawn/files/";
      destDir = "dropbox:";
    };
    backup-usb = {
      enable = true;
      package = fPkgs.backup-usb;
      device = {
        idVendor = "04fc";
        idProduct = "0c25";
        partition = "2";
      };
      mountPoint = "/media/usb_backup_ela";
      backupPath = "/media/daniela/";
    };
    shutdown-wakeup = {
      enable = true;
      package = fPkgs.rtc-helper;
      shutdownTime = "0:00:00";
      wakeupTime = "12:00:00";
    };
    nextcloud = {
      enable = true;
      hostName = "next.tank.pointjig.de";
      adminPasswordFile = secrets.nextcloud-admin.path;
      notify_push.package = pkgs.nextcloud-notify_push;
      home = "/persist/var/lib/nextcloud";
      package = pkgs.nextcloud31;
      prometheus.passwordFile = secrets.prometheus-nextcloud.path;
    };
    postgresql = {
      enable = true;
      package = pkgs.postgresql_17;
      dataDir = "/persist/var/lib/postgresql/17";
    };
    hydra = {
      enable = true;
      hostName = "hydra.pointjig.de";
      mailAdress = "hydra@pointjig.de";
      githubHookFile = config.sops.templates."hydra-hook-token.conf".path;
      writeTokenFile = config.sops.templates."hydra-write-token.conf".path;
      builder.sshKeyFile = secrets.ssh-builder-key.path;
      attic.enable = true;
      cachix = {
        enable = false;
        cacheName = "shawn8901";
        signingKeyFile = secrets.cachix_signing_key.path;
        cachixTokenFile = secrets.cachix_token_file.path;
      };
    };
    server.enable = true;
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
        (pkgs.callPackage ../../packages/pg-upgrade {
          inherit
            oldPackage
            oldBin
            newPackage
            newBin
            ;
        })
      ];
  };
}
