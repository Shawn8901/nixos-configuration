{ modulesPath, pkgs, ... }:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    (modulesPath + "/profiles/minimal.nix")
  ];

  nixpkgs.hostPlatform.system = "x86_64-linux";

  boot = {
    kernelParams = [ "memhp_default_state=online" ];
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    zfs = {
      devNodes = "/dev/disk/by-partlabel";
      package = pkgs.zfs;
      forceImportRoot = false;
    };
  };
  hardware.facter.reportPath = ./facter.json;

}
