{ lib, config, ... }:
{
  imports = [
    ./vlagent.nix
    ./vmagent.nix
  ];

  options.includes.monitoree.enable = lib.mkEnableOption "Enables monitoree";

  config = lib.mkIf (config.includes.monitoree.enable) {
    includes.monitoree = {
      vlagent.enable = lib.mkDefault true;
      vmagent.enable = lib.mkDefault true;
    };
    services.smartd.enable = lib.mkDefault true;
  };

}
