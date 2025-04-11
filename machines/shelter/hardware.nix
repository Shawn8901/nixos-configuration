{ pkgs, modulesPath, ... }:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    (modulesPath + "/profiles/minimal.nix")
  ];

  boot = {
    initrd.availableKernelModules = [
      "ata_piix"
      "uhci_hcd"
      "virtio_pci"
      "sr_mod"
      "virtio_blk"
    ];
    kernelPackages = pkgs.linuxPackages;
    zfs = {
      devNodes = "/dev/";
      extraPools = [ "zbackup" ];
      requestEncryptionCredentials = false;
    };
    extraModprobeConfig = ''
      options zfs zfs_arc_max=134217728
    '';
    supportedFilesystems = [ "zfs" ];
    loader.grub.enable = true;
  };

  hardware.cpu.intel.updateMicrocode = true;
}
