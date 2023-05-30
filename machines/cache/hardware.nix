{modulesPath, ...}: {
  imports = [(modulesPath + "/profiles/qemu-guest.nix") (modulesPath + "/profiles/minimal.nix")];
  boot = {
    cleanTmpDir = true;
    initrd = {
      availableKernelModules = ["ata_piix" "uhci_hcd" "xen_blkfront" "xhci_pci" "usbhid"];
      kernelModules = ["nvme"];
    };
    loader = {
      efi.efiSysMountPoint = "/boot/efi";
      grub = {
        efiSupport = true;
        efiInstallAsRemovable = true;
        device = "nodev";
      };
    };
  };
  fileSystems = {
    "/boot/efi" = {
      device = "/dev/disk/by-uuid/FBA9-6926";
      fsType = "vfat";
    };
    "/" = {
      device = "/dev/sda1";
      fsType = "ext4";
    };
  };
  zramSwap.enable = true;
}
