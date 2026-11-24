{
  options,
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.includes.mailserver;
in
{
  options.includes.mailserver = {
    enable = lib.mkEnableOption "Enables mailserver";
    fqdn = lib.mkOption {
      type = lib.types.str;
      default = config.mailserver.fqdn;
      description = "The fully qualified domain name of the mailserver.";
    };
    domain = lib.mkOption {
      type = lib.types.str;
      default = "pointjig.de";
      description = "The fully qualified domain name of the mailserver.";
    };
    syncFromFQDN = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Fully qualified domain name of the mailserver we copy from";
    };
  };

  config = lib.optionalAttrs (options ? mailserver) {
    sops.secrets = {
      snm-shawn.sopsFile = ./secrets.yaml;
      snm-dorman.sopsFile = ./secrets.yaml;
    };
    services = {
      nginx = {
        enable = true;
        virtualHosts.${cfg.fqdn}.enableACME = true;
      };
      knot-resolver.enable = true;
      resolved.enable = false;
    };
    mailserver = {
      enable = true;
      stateVersion = 4;
      domains = [ cfg.domain ];
      x509.useACMEHost = cfg.fqdn;
      accounts = {
        "shawn@pointjig.de".passwordFile = config.sops.secrets.snm-shawn.path;
        "dorman@pointjig.de".passwordFile = config.sops.secrets.snm-dorman.path;
      };
    };

    systemd = lib.mkIf (cfg.syncFromFQDN != null) {
      services.imapsync = {
        path = [ pkgs.imapsync ];
        script = "${
          (lib.concatStringsSep "\n" (
            lib.mapAttrsToList (
              account: config:
              "imapsync --host1 ${cfg.syncFromFQDN} --user1 ${account} --passfile1 ${config.passwordFile} --host2 ${cfg.fqdn} --user2 ${account} --passfile2 ${config.passwordFile}"
            ) config.mailserver.accounts
          ))
        }";
      };
      timers.imapsync = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = [ "daily" ];
          Persistent = true;
          OnBootSec = "15min";
        };
      };
    };
  };
}
