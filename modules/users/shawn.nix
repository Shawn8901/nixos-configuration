{
  config,
  lib,
  ...
}:
{
  options.includes.managed-users.shawn.enable = lib.mkEnableOption "Enables managed user shawn";

  config = lib.mkIf (config.includes.managed-users.shawn.enable) {

    sops.secrets.shawn = {
      sopsFile = ./secrets.yaml;
      neededForUsers = true;
    };

    users.users.shawn = {
      isNormalUser = true;
      group = "users";
      extraGroups = [
        "wheel"
        "networkmanager"
      ];
      uid = 1000;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMguHbKev03NMawY9MX6MEhRhd6+h2a/aPIOorgfB5oM shawn"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC/rjtEHE+1bG9mS0RPgH1AVEYzVEfsJ24H+ZKaxVNDN smartphone"
      ];
      hashedPasswordFile = config.sops.secrets.shawn.path;
    };
    nix.settings.trusted-users = [ "shawn" ];
  };
}
