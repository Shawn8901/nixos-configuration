{
  config,
  modulesPath,
  ...
}:
{
  nixpkgs.hostPlatform.system = "x86_64-linux";
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];
  boot = {
    kernelParams = [
      "pci=noaer"
      "rd.systemd.debug_shell=1"
      "rd.systemd.unit=initrd.target"
    ];
    extraModulePackages = with config.boot.kernelPackages; [ it87 ];
    extraModprobeConfig = ''
      options zfs zfs_arc_max=2147483648
      options it87 ignore_resource_conflict=1 force_id=0x862
    '';
    supportedFilesystems = [
      "zfs"
      "ntfs"
    ];
    zfs = {
      devNodes = "/dev/disk/by-partlabel";
      requestEncryptionCredentials = [ "ztank" ];
      extraPools = [ "ztank" ];
      forceImportRoot = false;
    };
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    tmp.useTmpfs = false;
    initrd = {
      systemd.services.sops-install-secret-for-users.unitConfig.X-StopOnFailure = true;
      network = {
        ssh = {
          enable = true;
          port = 2225;
          authorizedKeys = config.users.users.shawn.openssh.authorizedKeys.keys;
        };
      };
    };
  };
  hardware.facter.reportPath = ./facter.json;
  fileSystems."/var/log".neededForBoot = true;
}
