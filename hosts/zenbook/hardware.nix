{
  config,
  modulesPath,
  ...
}:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  nixpkgs.hostPlatform.system = "x86_64-linux";
  boot = {
    initrd.availableKernelModules = [
      "nvme"
      "xhci_pci"
      "rtsx_pci_sdmmc"
      "usbhid"
      "sd_mod"
      "sr_mod"
    ];
    kernelModules = [
      "kvm-amd"
      "cifs"
      "usb_storage"
      "amdgpu"
    ];
    kernelParams = [
      "initcall_blacklist=acpi_cpufreq_init"
      "amd_pstate=passive"
      "amd_pstate.shared_mem=1"
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
    zfs = {
      devNodes = "/dev/disk/by-partlabel";
      forceImportRoot = false;
    };
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  fileSystems."/var/log".neededForBoot = true;
  hardware = {
    cpu.amd.updateMicrocode = true;
    enableRedistributableFirmware = true;
  };
  powerManagement.enable = true;
}
