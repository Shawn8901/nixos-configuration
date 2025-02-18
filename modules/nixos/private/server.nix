{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.shawn8901.server;
in
{
  options = {
    shawn8901.server = {
      enable = mkEnableOption "server config for nixos";
    };
  };
  config = mkIf cfg.enable {
    environment = {
      systemPackages = [
        pkgs.gitMinimal
        pkgs.btop
        (pkgs.nixos-rebuild.override { nix = config.nix.package.out; })
      ];
    };

    system.autoUpgrade = {
      enable = true;
      dates = "05:14";
      flake = "github:shawn8901/nixos-configuration";
      allowReboot = true;
      persistent = true;
    };

    networking = {
      firewall.logRefusedConnections = false;
      networkmanager.enable = false;
      nftables.enable = true;
      dhcpcd.enable = false;
      useNetworkd = true;
      useDHCP = lib.mkDefault false;
    };

    hardware.bluetooth.enable = false;
    security.acme = {
      acceptTerms = true;
      defaults.email = lib.mkDefault "shawn@pointjig.de";
    };

    programs.nano.enable = false;
    services = {
      logrotate.enable = true;
      qemuGuest.enable = true;
      resolved = {
        enable = true;
        llmnr = "false";
      };
      vnstat.enable = true;
      openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
        };
      };
      fail2ban = {
        enable = true;
        maxretry = 3;
        bantime = "1h";
        bantime-increment.enable = true;
        ignoreIP = [ "192.168.11.0/24" ];
      };
    };
  };
}
