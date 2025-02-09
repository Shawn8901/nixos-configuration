{
  self',
  self,
  config,
  flakeConfig,
  pkgs,
  lib,
  ...
}:
let
  hosts = self.nixosConfigurations;
  fPkgs = self'.packages;

  inherit (config.sops) secrets;
  inherit (lib) concatStringsSep;

  immichName = "immich.tank.pointjig.de";
  vaultwardenName = "vaultwarden.tank.pointjig.de";
in
{
  sops.secrets = lib.mkMerge [
    {
      ssh-builder-key = {
        owner = "hydra-queue-runner";
      };
      zfs-ztank-key = { };
      zrepl = { };
      ela = { };
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
      github-write-token = {
        owner = "hydra-queue-runner";
        group = "hydra";
      };
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
    }
    (lib.optionalAttrs config.services.stalwart-mail.enable {
      stalwart-fallback-admin = {
        owner = "stalwart-mail";
        group = "stalwart-mail";
      };
    })
  ];

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
          maxJobs = hosts.pointalpha.config.nix.settings.max-jobs;
          systemFeatures = hosts.pointalpha.config.nix.settings.system-features;
        in
        {
          script = ''
            if ${pkgs.iputils}/bin/ping -c1 -w 1 pointalpha > /dev/null; then
              if ! grep pointalpha /tmp/hyda/dynamic-machines > /dev/null; then
                echo "ssh://root@pointalpha x86_64-linux,i686-linux ${secrets.ssh-builder-key.path} ${toString maxJobs} 4 ${concatStringsSep "," systemFeatures} - -" >  /tmp/hyda/dynamic-machines \
                echo "Added pointalpha to dynamic build machines"
              fi
            else
              if grep pointalpha /tmp/hyda/dynamic-machines > /dev/null; then
                echo "" > /tmp/hyda/dynamic-machines && echo "Cleared dynamic build machines"
              fi
            fi
          '';
        };
      vaultwarden = {
        after = [ "postgresql.service" ];
        requires = [ "postgresql.service" ];
        serviceConfig = {
          StateDirectory = lib.mkForce "vaultwarden"; # modules defaults to bitwarden_rs
        };
      };
    };
    timers.pointalpha-online = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/1";
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
    vaultwarden = {
      enable = true;
      dbBackend = "postgresql";
      config = {
        DATABASE_URL = "postgresql:///vaultwarden?host=/run/postgresql";
        DOMAIN = "https://${vaultwardenName}";
        DATA_FOLDER = "/var/lib/vaultwarden";
        ENABLE_WEBSOCKET = true;
        LOG_LEVEL = "warn";
        PASSWORD_ITERATIONS = 600000;
        ROCKET_ADDRESS = "127.0.0.1";
        ROCKET_PORT = 8222;
        SIGNUPS_VERIFY = true;
        TRASH_AUTO_DELETE_DAYS = 30;
      };
    };
    openssh.hostKeys = [
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
        global.monitoring = [
          {
            type = "prometheus";
            listen = ":9811";
            listen_freebind = true;
          }
        ];
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
              type = "tls";
              address = "sapsrv01.clansap.org:8888";
              ca = ../../files/public_certs/zrepl/sapsrv01.crt;
              cert = ../../files/public_certs/zrepl/tank.crt;
              key = secrets.zrepl.path;
              server_cn = "sapsrv01";
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
              type = "tls";
              address = "sapsrv02.clansap.org:8888";
              ca = ../../files/public_certs/zrepl/sapsrv02.crt;
              cert = ../../files/public_certs/zrepl/tank.crt;
              key = secrets.zrepl.path;
              server_cn = "sapsrv02";
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
        "${vaultwardenName}" = {
          serverName = vaultwardenName;
          forceSSL = true;
          enableACME = true;
          http3 = true;
          kTLS = true;
          locations."/" = {
            proxyPass = "http://localhost:${toString config.services.vaultwarden.config.ROCKET_PORT}";
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
        "vaultwarden"
      ];
      ensureUsers = [
        {
          name = "stalwart-mail";
          ensureDBOwnership = true;
        }
        {
          name = "vaultwarden";
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
    User = "stalwart-mail";
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
      wakeupTime = "15:00:00";
    };
    nextcloud = {
      enable = true;
      hostName = "next.tank.pointjig.de";
      adminPasswordFile = secrets.nextcloud-admin.path;
      notify_push.package = pkgs.nextcloud-notify_push;
      home = "/persist/var/lib/nextcloud";
      package = pkgs.nextcloud30;
      prometheus.passwordFile = secrets.prometheus-nextcloud.path;
    };
    postgresql = {
      enable = true;
      package = pkgs.postgresql_16;
      dataDir = "/persist/var/lib/postgresql/16";
    };
    hydra = {
      enable = true;
      hostName = "hydra.pointjig.de";
      mailAdress = "hydra@pointjig.de";
      writeTokenFile = secrets.github-write-token.path;
      builder.sshKeyFile = secrets.ssh-builder-key.path;
      attic.enable = true;
    };
    server.enable = true;
  };

  environment.etc.".ztank_key".source = secrets.zfs-ztank-key.path;
}
