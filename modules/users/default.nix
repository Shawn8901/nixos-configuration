{ config, lib, ... }:
{
  imports = [
    ./root.nix
    ./shawn.nix
  ];

  options.includes.managed-users.enable = lib.mkEnableOption "Enables managed-users";

  config = lib.mkIf (config.includes.managed-users.enable) {
    includes = {
      managed-users = {
        shawn.enable = lib.mkDefault true;
        root.enable = lib.mkDefault true;
      };
      shell.enable = lib.mkDefault true;
    };
  };
}
