{
  pkgs,
  modulesPath,
  ...
}:
let
  zfsOptions = [
    "zfsutil"
    "X-mount.mkdir"
  ];
in
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot = {
    initrd = {
      availableKernelModules = [
        "ahci"
        "xhci_pci"
        "usbhid"
        "sd_mod"
        "sr_mod"
      ];
      systemd.enable = true;
    };
    kernelModules = [
      "kvm-amd"
      "cifs"
      "usb_storage"
      "k10temp"
      "ntsync"
      "sg"
    ];
    kernelPackages = pkgs.linuxPackages_6_15;
    extraModprobeConfig = ''
      options zfs zfs_arc_max=4294967296
      options nct6775 force_id=0xd420
    '';
    supportedFilesystems = [
      "zfs"
      "ntfs"
    ];
    zfs = {
      devNodes = "/dev/disk/by-id";
      package = pkgs.zfs_2_3;
    };
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    tmp.useTmpfs = false;
  };

  fileSystems = {
    "/" = {
      device = "rpool/local/root";
      fsType = "zfs";
      options = zfsOptions;
    };

    "/var/log" = {
      device = "rpool/local/log";
      fsType = "zfs";
      options = zfsOptions;
      neededForBoot = true;
    };

    "/persist" = {
      device = "rpool/safe/persist";
      fsType = "zfs";
      options = zfsOptions;
      neededForBoot = true;
    };

    "/nix" = {
      device = "rpool/local/nix";
      fsType = "zfs";
      options = zfsOptions;
    };

    "/home" = {
      device = "rpool/safe/home";
      fsType = "zfs";
      options = zfsOptions;
    };

    "/steamlibrary" = {
      device = "rpool/local/steamlibrary";
      fsType = "zfs";
      options = zfsOptions;
    };

    "/boot" = {
      device = "/dev/disk/by-label/EFI";
      fsType = "vfat";
      options = [
        "x-systemd.idle-timeout=1min"
        "x-systemd.automount"
        "noauto"
      ];
    };
  };

  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;
}
