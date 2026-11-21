{
  sources,
  config,
  pkgs,
  lib,
  modulesPath,
  ...
}:
let
  inherit (config.sops) secrets;
in
{
  imports = [
    "${modulesPath}/profiles/perlless.nix"
    ./hardware.nix
    "${sources.preservation}/module.nix"
    ./preservation.nix
    "${sources.disko}/module.nix"
    ./disko-config.nix
    ./home-assistant.nix
  ];

  # system.forbiddenDependenciesRegexes = lib.mkForce [ ];

  sops = {
    defaultSopsFile = ./secrets.yaml;
    secrets = {
      zrepl = { };
      prometheus-fritzbox = {
        owner = config.services.prometheus.exporters.fritz.user;
        inherit (config.services.prometheus.exporters.fritz) group;
      };
    };
  };

  includes = {
    monitoree.enable = true;
    server.enable = true;
    postgresql.enable = true;
    managed-users.enable = true;
    zfs.enable = true;
    zrepl.enable = true;
  };

  networking.hosts = {
    "127.0.0.1" = lib.attrNames config.services.nginx.virtualHosts;
    "::1" = lib.attrNames config.services.nginx.virtualHosts;
  };

  systemd = {
    network = {
      enable = true;
      networks."20-wired" = {
        matchConfig.Name = "enp0s31f6";
        networkConfig.DHCP = "yes";
        networkConfig.Domains = "fritz.box ~box ~.";
      };
      wait-online.anyInterface = true;
    };
    services.prometheus-fritz-exporter = {
      requires = [ "network-online.target" ];
      after = [ "network-online.target" ];
    };

    tmpfiles.rules = [
      "w /sys/devices/system/cpu/cpufreq/policy?/energy_performance_preference - - - - balance_power"
    ];
  };
  services = {
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
    zfs.autoScrub.pools = [ "rpool" ];
    zrepl.settings.jobs = [
      {
        name = "beacon_safe";
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
          ca = ../../hosts/tank/zrepl.crt;
          cert = ./zrepl.crt;
          key = config.sops.secrets.zrepl.path;
          client_cns = [ "tank" ];
        };
      }
    ];
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };
    smartd.devices = [ { device = "/dev/sda"; } ];
    prometheus.exporters.fritz = {
      enable = true;
      listenAddress = "127.0.0.1";
      settings.devices = [
        {
          hostname = "192.168.11.1";
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
    postgresql = {
      package = pkgs.postgresql_17;
      dataDir = "/persist/var/lib/postgresql/17";
    };
  };

  environment.systemPackages =
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
  powerManagement = {
    enable = true;
    powertop.enable = true;
    cpuFreqGovernor = "schedutil";
  };
}
