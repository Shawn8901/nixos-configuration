{
  den.aspects.watchtower.nixos =
    {
      config,
      ...
    }:
    {
      sops.secrets.victoriametrics = { };
      services = {
        nginx.virtualHosts."vm.pointjig.de" = {
          enableACME = true;
          forceSSL = true;
          http3 = true;
          kTLS = true;
          locations."/" = {
            proxyPass = "http://${config.services.victoriametrics.listenAddress}";
            proxyWebsockets = true;
            recommendedProxySettings = true;
          };
        };
        victoriametrics = {
          enable = true;
          retentionPeriod = "1y";
          listenAddress = "127.0.0.1:8427";
          basicAuthUsername = "vm";
          basicAuthPasswordFile = config.sops.secrets.victoriametrics.path;
          extraOptions = [
            "-selfScrapeInterval=10s"
            "-selfScrapeInstance=${config.networking.hostName}"
          ];
        };
      };
    };
}
