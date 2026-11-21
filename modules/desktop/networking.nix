{ config, lib, ... }:
{
  options.includes.desktop.networking.enable = lib.mkEnableOption "Enables desktop networking";

  config = lib.mkIf (config.includes.desktop.networking.enable) {

    networking = {
      networkmanager = {
        enable = true;
        plugins = lib.mkForce [ ];
      };
      nftables.enable = true;
      dhcpcd.enable = false;
      useNetworkd = false;
      useDHCP = false;
    };
    systemd.network.wait-online.anyInterface = true;
    services.resolved.enable = false;
  };
}
