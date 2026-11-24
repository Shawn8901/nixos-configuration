{
  pkgs,
  config,
  lib,
  ...
}:
{
  options.includes.server.enable = lib.mkEnableOption "Enable server configurations";

  config = lib.mkIf (config.includes.server.enable) {
    environment = {
      systemPackages = [
        pkgs.gitMinimal
        pkgs.btop
      ];
    };
    networking = {
      firewall.logRefusedConnections = lib.mkDefault true;
      networkmanager.enable = false;
      nftables.enable = true;
      dhcpcd.enable = lib.mkDefault false;
      useNetworkd = lib.mkDefault true;
    };
    hardware = {
      bluetooth.enable = lib.mkDefault false;
      graphics.enable = false;
    };
    security.acme = {
      acceptTerms = true;
      defaults.email = lib.mkDefault "shawn@pointjig.de";
    };
    services = {
      logrotate.enable = true;
      qemuGuest.enable = true;
      resolved = {
        enable = lib.mkDefault true;
        settings.Resolve.LLMNR = "false";
      };
      vnstat.enable = true;
      openssh = {
        enable = true;
        ports = [ 2242 ];
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
        };
      };
      fail2ban = {
        enable = true;
        maxretry = 3;
        bantime = "24h";
        bantime-increment.enable = true;
      };
      custom-auto-upgrade = {
        enable = true;
        url = "https://github.com/shawn8901/nixos-configuration";
        dates = "04:00";
      };
    };
  };
}
