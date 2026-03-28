{
  cfg.desktop.provides.networking = {
    nixos =
      { lib, ... }:
      {
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
  };
}
