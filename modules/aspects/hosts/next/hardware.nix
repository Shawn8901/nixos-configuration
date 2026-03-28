{
  den.aspects.next.nixos =
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
        device = "/dev/disk/by-uuid/6e32d049-bc7e-4382-b989-3c5eca7bc8ef";
        fsType = "ext4";
      };

      fileSystems."/boot" = {
        device = "/dev/disk/by-uuid/1AFE-DFCF";
        fsType = "vfat";
      };

      swapDevices = [ { device = "/dev/disk/by-uuid/6f049e18-ba0e-478b-a917-775abca0d3c2"; } ];

      hardware.cpu.intel.updateMicrocode = true;
    };
}
