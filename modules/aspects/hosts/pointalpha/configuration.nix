{
  cfg,
  den,
  self,
  ...
}:
{
  den.aspects.pointalpha.provides.to-users = {
    includes = [
      cfg.desktop
      cfg.gaming
      cfg.monitoree
      cfg.perlless
      cfg.printer
      cfg.remote-builder
      cfg.zfs
      cfg.zrepl
      cfg.zrepl-admin
      (den.provides.unfree [
        "keymapp"
        "makemkv"
      ])
    ];

    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.keymapp
          pkgs.portfolio
          #pkgs.pytr
          #fPkgs.jameica-fhs
          pkgs.jameica
          pkgs.makemkv
          pkgs.libation
          (pkgs.asunder.override { mp3Support = true; })
          pkgs.deezer-enhanced
        ];

        programs.zsh.shellAliases =
          let
            mount_script =
              path: credential:
              "sudo mount -t cifs //tank.fritz.box/${path} /media/nas -o credentials=${credential},iocharset=utf8,uid=1000,gid=100,forcegid,forceuid,vers=3.0";
          in
          {
            nas_mount = (mount_script "joerg" "/etc/samba/credentials_shawn");
            nas_mount_ela = (mount_script "ela" "/etc/samba/credentials_ela");
            nas_umount = "sudo umount /media/nas";
          };

        systemd.user.tmpfiles.rules = [
          "d /media/nas 0750"
        ];
      };

    nixos =
      {
        pkgs,
        config,
        ...
      }:
      {
        sops = {
          defaultSopsFile = ./secrets.yaml;
          secrets.zrepl = { };
        };

        environment.systemPackages = [
          pkgs.solaar
          pkgs.android-tools
        ];

        nix.settings = {
          keep-outputs = true;
          keep-derivations = true;
          cores = 8;
          http2 = false;
        };

        services = {
          smartd = {
            enable = true;
            devices = [ { device = "/dev/nvme1"; } ];
          };
          pipewire = {
            wireplumber.extraConfig = {
              "10-bluez"."monitor.bluez.properties" = {
                "bluez5.enable-sbc-xq" = true;
                "bluez5.enable-msbc" = true;
                "bluez5.enable-hw-volume" = true;
              };
              "11-bluetooth-policy"."wireplumber.settings"."bluetooth.autoswitch-to-headset-profile" = false;
            };
          };
          zrepl.settings.jobs = [
            {
              name = "pointalpha_safe";
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
                ca = self.outPath + "/files/certs/zrepl/tank.crt";
                cert = self.outPath + "/files/certs/zrepl/pointalpha.crt";
                key = config.sops.secrets.zrepl.path;
                client_cns = [ "tank" ];
              };
            }
          ];
        };

        programs = {
          ausweisapp = {
            enable = true;
            openFirewall = true;
          };
          nh.flake = "/home/shawn/dev/nixos-configuration";
          kdeconnect.enable = true;
          droidcam.enable = true;
        };

      };

  };
}
