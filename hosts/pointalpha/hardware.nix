{ pkgs, ... }:
let
  _1GB = 1024 * 1024 * 1024;
in
{
  nixpkgs.hostPlatform.system = "x86_64-linux";

  boot = {
    kernelPackages = pkgs.linuxPackages;
    extraModprobeConfig = ''
      options zfs zfs_arc_max=${toString (6 * _1GB)}
      options nct6775 force_id=0xd420
    '';
    supportedFilesystems = [
      "zfs"
      "ntfs"
    ];
    zfs = {
      devNodes = "/dev/disk/by-id";
      package = pkgs.zfs;
      forceImportRoot = false;
    };
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    tmp.useTmpfs = false;
  };
  hardware.facter.reportPath = ./facter.json;
  fileSystems."/var/log".neededForBoot = true;
}
