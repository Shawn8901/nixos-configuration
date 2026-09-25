{ inputs, ... }:
{
  den.aspects.beacon.nixos = {
    imports = [
      inputs.disko.nixosModules.disko
    ];
    disko.devices = {
      disk = {
        main = {
          type = "disk";
          device = "/dev/sda";
          content = {
            type = "gpt";
            partitions = {
              ESP = {
                type = "EF00";
                size = "500M";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                  mountOptions = [ "umask=0077" ];
                };
              };
              swap = {
                size = "6G";
                label = "SWAP";
                content = {
                  type = "swap";
                  discardPolicy = "both";
                };
              };
              root = {
                size = "100%";
                label = "ROOTFS";
                content = {
                  type = "zfs";
                  pool = "rpool";
                };
              };
            };
          };
        };
      };
      zpool = {
        rpool = {
          type = "zpool";
          options = {
            ashift = "12";
          };
          rootFsOptions = {
            compression = "zstd";
            atime = "off";
            relatime = "off";
            canmount = "off";
            acltype = "posix";
            mountpoint = "none";
            xattr = "sa";
            normalization = "formD";
          };

          datasets = {
            "local/root" = {
              type = "zfs_fs";
              mountpoint = "/";
              postCreateHook = "zfs list -t snapshot -H -o name | grep -E '^rpool/local/root@blank$' || zfs snapshot rpool/local/root@blank";
            };
            "local/log" = {
              type = "zfs_fs";
              mountpoint = "/var/log";
            };
            "local/nix" = {
              type = "zfs_fs";
              mountpoint = "/nix";
            };
            "reserved" = {
              type = "zfs_fs";
              mountpoint = null;
              options.refreservation = "1G";
            };
            "safe/home" = {
              type = "zfs_fs";
              mountpoint = "/home";
            };
            "safe/persist" = {
              type = "zfs_fs";
              mountpoint = "/persist";
            };
          };
        };
      };
    };
  };
}
