{
  den.aspects.pointjig.nixos =
    { pkgs, modulesPath, ... }:
    {
      imports = [
        (modulesPath + "/profiles/qemu-guest.nix")
        (modulesPath + "/profiles/minimal.nix")
      ];

      boot = {
        initrd.availableKernelModules = [
          "uhci_hcd"
          "ehci_pci"
          "ahci"
          "sd_mod"
          "sr_mod"
        ];
        kernelPackages = pkgs.linuxPackages;
        kernelParams = [ "memhp_default_state=online" ];
        loader.grub = {
          enable = true;
          device = "/dev/sda";
        };
      };

      fileSystems."/" = {
        device = "/dev/disk/by-uuid/03dd5cae-8689-4b89-9c73-854ba799f2fd";
        fsType = "ext4";
      };

      fileSystems."/boot" = {
        device = "/dev/disk/by-uuid/E588-9EBB";
        fsType = "vfat";
      };

      swapDevices = [ { device = "/dev/disk/by-uuid/d9ea5a2c-63a9-4ec3-9168-977a6898c722"; } ];

      hardware.cpu.intel.updateMicrocode = true;
    };
}
