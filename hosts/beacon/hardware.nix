{ pkgs, ... }:
let
  _1GB = 1024 * 1024 * 1024;
in
{

  boot = {
    extraModprobeConfig = ''
      options zfs zfs_arc_max=${toString _1GB}
    '';
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    zfs = {
      devNodes = "/dev/disk/by-partlabel";
      forceImportRoot = false;
    };
  };
  nixpkgs.hostPlatform.system = "x86_64-linux";
  hardware = {
    facter.reportPath = ./facter.json;
    cpu.intel.updateMicrocode = true;
    enableRedistributableFirmware = true;
    bluetooth = {
      enable = true;
      package = pkgs.bluez5-experimental;
      settings.General.Experimental = true;
      input.General.ClassicBondedOnly = false;
    };
  };
  fileSystems."/var/log".neededForBoot = true;
}
