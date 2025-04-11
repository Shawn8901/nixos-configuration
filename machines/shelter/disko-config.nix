{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1M";
              type = "EF02"; # for grub MBR
              priority = 1;
            };
            root = {
              size = "44G";
              label = "ROOTFS";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
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

            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zbackup";
              };
            };
          };
        };
      };
    };
    zpool = {
      zbackup = {
        type = "zpool";
        rootFsOptions = {
          acltype = "posixacl";
          atime = "off";
          mountpoint = "none";
          xattr = "sa";
        };
        options.ashift = "12";
        datasets = {
          "replica" = {
            type = "zfs_fs";
            options.mountpoint = "none";
          };
        };
      };
    };
  };
}
