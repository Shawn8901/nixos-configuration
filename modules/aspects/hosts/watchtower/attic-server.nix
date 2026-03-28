{
  den.aspects.watchtower.nixos =
    {
      lib,
      config,
      ...
    }:
    {
      sops.secrets.attic-env = { };
      networking.firewall = {
        allowedUDPPorts = [ 443 ];
        allowedTCPPorts = [
          80
          443
        ];
      };

      services = {
        nginx = {
          enable = lib.mkDefault true;
          recommendedGzipSettings = true;
          recommendedOptimisation = true;
          recommendedTlsSettings = true;
          recommendedProxySettings = true;
          clientMaxBodySize = "2G";
          virtualHosts."cache.pointjig.de" = {
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
        atticd = {
          environmentFile = config.sops.secrets.attic-env.path;
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
