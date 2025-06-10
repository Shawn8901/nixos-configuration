{
  pkgs,
  lib,
  config,
  ...
}:
let
  inherit (lib)
    types
    mkEnableOption
    mkPackageOption
    mkOption
    mkDefault
    mkIf
    ;

  cfg = config.shawn8901.attic;
in
{
  options = {
    shawn8901.attic = {
      enable = mkEnableOption "Enables a preconfigured attic instance";
      hostName = mkOption {
        type = types.str;
        description = "full qualified hostname of the attic instance";
      };
      package = mkPackageOption pkgs "attic-server" { };
      environmentFile = mkOption { type = types.path; };
    };
  };
  config = mkIf cfg.enable {
    networking.firewall = {
      allowedUDPPorts = [ 443 ];
      allowedTCPPorts = [
        80
        443
      ];
    };

    services = {
      nginx = {
        enable = mkDefault true;
        recommendedBrotliSettings = true;
        recommendedGzipSettings = true;
        recommendedOptimisation = true;
        recommendedTlsSettings = true;
        recommendedZstdSettings = true;
        recommendedProxySettings = true;
        clientMaxBodySize = "2G";
        virtualHosts = {
          "${cfg.hostName}" = {
            enableACME = true;
            forceSSL = true;
            http3 = false;
            http2 = false;
            kTLS = true;
            extraConfig = ''
              client_header_buffer_size 64k;
            '';
            locations."/" = {
              proxyPass = "http://127.0.0.1:8080";
              recommendedProxySettings = true;
            };
          };
        };
      };
      atticd = {
        inherit (cfg) package environmentFile;
        enable = true;
        settings = {
          database = {
            url = "postgresql:///atticd?host=/run/postgresql";
            heartbeat = true;
          };
          compression.type = "zstd";
          garbage-collection = {
            interval = "12 hours";
            default-retention-period = "1 months";
          };
        };
      };
      postgresql = {
        ensureDatabases = [ "atticd" ];
        ensureUsers = [
          {
            name = "atticd";
            ensureDBOwnership = true;
          }
        ];
      };
    };
  };
}
