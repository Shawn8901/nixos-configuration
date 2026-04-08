{
  cfg.server.nixos =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      environment = {
        systemPackages = [
          pkgs.gitMinimal
          pkgs.btop
          (pkgs.nixos-rebuild.override { nix = config.nix.package.out; })
        ];
      };

      system.autoUpgrade = {
        enable = lib.mkDefault true;
        dates = lib.mkDefault "05:14";
        flake = lib.mkDefault "github:shawn8901/nixos-configuration";
        allowReboot = true;
        persistent = true;
      };

      networking = {
        firewall.logRefusedConnections = lib.mkDefault false;
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
      };
    };
}
