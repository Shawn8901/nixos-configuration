{
  den.aspects.watchtower.nixos =
    {
      config,
      ...
    }:
    {
      sops.secrets.victorialogs = { };
      services = {
        nginx.virtualHosts."vl.pointjig.de" = {
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
        victorialogs = {
          enable = true;
          listenAddress = "127.0.0.1:9428";
          basicAuthUsername = "vl";
          basicAuthPasswordFile = config.sops.secrets.victorialogs.path;
        };
      };
    };
}
