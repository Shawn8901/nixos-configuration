{
  den.aspects.beacon.nixos =
    { modulesPath, ... }:
    {
      imports = [
        (modulesPath + "/installer/scan/not-detected.nix")
      ];

      boot = {
        initrd = {
          availableKernelModules = [
            "xhci_pci"
            "thunderbolt"
            "ahci"
            "usb_storage"
            "usbhid"
            "sd_mod"
            "sdhci_pci"
          ];
          systemd.enable = true;
        };
        kernelModules = [ "kvm-intel" ];
        loader = {
          systemd-boot.enable = true;
          efi.canTouchEfiVariables = true;
        };
        zfs = {
          devNodes = "/dev/disk/by-id";
          forceImportRoot = false;
        };
      };
      nixpkgs.hostPlatform.system = "x86_64-linux";
      hardware = {
        cpu.intel.updateMicrocode = true;
        enableRedistributableFirmware = true;
      };

      fileSystems = {
        "/persist".neededForBoot = true;
        "/var/log".neededForBoot = true;
      };
    };

}
