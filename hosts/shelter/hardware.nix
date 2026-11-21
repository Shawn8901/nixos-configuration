{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    (modulesPath + "/profiles/minimal.nix")
  ];
  nixpkgs.hostPlatform.system = "x86_64-linux";
  hardware.facter.reportPath = ./facter.json;
  boot = {
    zfs = {
      devNodes = "/dev/disk/by-partlabel";
      extraPools = [ "zbackup" ];
      requestEncryptionCredentials = false;
      forceImportRoot = false;
    };
    extraModprobeConfig = ''
      options zfs zfs_arc_max=134217728
    '';
    supportedFilesystems = [ "zfs" ];
    loader.grub.enable = true;
  };
}
