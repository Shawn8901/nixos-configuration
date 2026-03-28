{
  den.aspects.watchtower.nixos =
    {
      config,
      ...
    }:
    {
      sops.secrets.victorialogs = { };
      services = {
        nginx = {
          enable = true;
          recommendedGzipSettings = true;
          recommendedOptimisation = true;
          recommendedTlsSettings = true;
          virtualHosts."vl.pointjig.de" = {
            enableACME = true;
            forceSSL = true;
            http3 = true;
            kTLS = true;
            locations."/" = {
              proxyPass = "http://${config.services.victorialogs.listenAddress}";
              proxyWebsockets = true;
              recommendedProxySettings = true;
            };
          };
        };
        victorialogs = {
          enable = true;
          listenAddress = "localhost:9428";
          basicAuthUsername = "vl";
          basicAuthPasswordFile = config.sops.secrets.victorialogs.path;
        };
      };
    };
}
