{
  den.aspects.zenbook.nixos =
    {
      config,
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
            "nvme"
            "xhci_pci"
            "rtsx_pci_sdmmc"
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
          "acpi_call"
          "amdgpu"
          "amd_pstate"
        ];
        kernelPackages = pkgs.linuxPackages;
        kernelParams = [
          "initcall_blacklist=acpi_cpufreq_init"
          "amd_pstate=passive"
          "amd_pstate.shared_mem=1"
          "amdgpu.dcfeaturemask=0x8"
        ];
        extraModulePackages = with config.boot.kernelPackages; [
          zenpower
          cpupower
        ];
        blacklistedKernelModules = [ "k10temp" ];
        extraModprobeConfig = ''
          options zfs zfs_arc_max=1610612736
        '';
        supportedFilesystems = [
          "zfs"
          "ntfs"
        ];
        zfs.devNodes = "/dev/disk/by-id";
        loader = {
          systemd-boot.enable = true;
          efi.canTouchEfiVariables = true;
        };
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
        "/boot" = {
          device = "/dev/disk/by-label/BOOT";
          fsType = "vfat";
          options = [
            "x-systemd.idle-timeout=1min"
            "x-systemd.automount"
            "noauto"
          ];
        };
      };
      swapDevices = [ { device = "/dev/disk/by-label/swap"; } ];

      hardware = {
        cpu.amd.updateMicrocode = true;
        enableRedistributableFirmware = true;
      };
      powerManagement.enable = true;
    };
}
