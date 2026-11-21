{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    (modulesPath + "/profiles/minimal.nix")
  ];

  nixpkgs.hostPlatform.system = "aarch64-linux";
  hardware.facter.reportPath = ./facter.json;
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    tmp.useTmpfs = false;
  };
}
