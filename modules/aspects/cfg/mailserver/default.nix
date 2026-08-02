{
  cfg.mailserver.nixos =
    { config, lib, ... }:
    {
      sops = {
        secrets = {
          snm-shawn.sopsFile = ./secrets.yaml;
          snm-dorman.sopsFile = ./secrets.yaml;
        };
      };

      mailserver = {
        enable = true;
        stateVersion = 4;
        domains = [ "pointjig.de" ];
        x509.useACMEHost = config.mailserver.fqdn;
        accounts = {
          "shawn@pointjig.de".hashedPasswordFile = config.sops.secrets.snm-shawn.path;
          "dorman@pointjig.de".hashedPasswordFile = config.sops.secrets.snm-dorman.path;
        };
      };
    };
}
