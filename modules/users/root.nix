{ config, lib, ... }:
{

  options.includes.managed-users.root.enable = lib.mkEnableOption "Enables managed root user";

  config = lib.mkIf (config.includes.managed-users.root.enable) {

    sops.secrets.root = {
      sopsFile = ./secrets.yaml;
      neededForUsers = true;
    };

    users.users.root.hashedPasswordFile = config.sops.secrets.root.path;
  };
}
