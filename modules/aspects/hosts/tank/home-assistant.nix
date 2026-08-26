{
  den.aspects.tank.provides.to-users.nixos =
    { config, pkgs, ... }:
    let
      haName = "ha.tank.pointjig.de";
      haPort = 8123;
    in
    {
      sops.secrets.hass-token = { };
      services = {
        home-assistant = {
          enable = true;
          extraComponents = [
            "androidtv_remote"
            "roomba"
            "matter"
            "otbr"
            "thread"
            "tplink_tapo"
            "epson"
            "picnic"
            "fritzbox"
            "prometheus"
          ];
          config = {
            http = {
              use_x_forwarded_for = true;
              trusted_proxies = [ "127.0.0.1" ];
              server_host = "127.0.0.1";
              server_port = haPort;
            };
            prometheus = {
              namespace = "hass";
            };
            default_config = { };
          };
          extraPackages =
            python3Packages: with python3Packages; [
              gtts
              pychromecast
            ];
          customComponents = [
            (pkgs.buildHomeAssistantComponent rec {
              owner = "Yeoh37";
              domain = "intex_wa510";
              version = "0.6.3";

              src = pkgs.fetchFromGitHub {
                owner = "Yeoh37";
                repo = "intex_wa510";
                tag = "v${version}";
                hash = "sha256-jOhPHz67A6JBt6pBh9DepU3U4UQ8C1wPxKKOcCdNnTQ=";
              };
            })
          ];
        };
        matterjs-server.enable = true;
        openthread-border-router = {
          enable = true;
          openFirewall = true;
          backboneInterfaces = [ "eno1" ];
          logLevel = "notice";
          radio = {
            device = "/dev/serial/by-id/usb-Nabu_Casa_ZBT-2_441BF685FD94-if00";
            baudRate = 460800;
          };
          web = {
            enable = true;
            listenAddress = "0.0.0.0";
          };
        };
        avahi = {
          enable = true;
          nssmdns4 = true;
          openFirewall = true;
        };
        vmagent.prometheusConfig.scrape_configs = [
          {
            job_name = "hass";
            static_configs = [
              {
                targets =
                  let
                    cfg = config.services.home-assistant.config.http;
                  in
                  [ "${cfg.server_host}:${toString cfg.server_port}" ];
              }
            ];
            scrape_interval = "15s";
            metrics_path = "/api/prometheus";
            bearer_token_file = "/run/credentials/vmagent.service/hass_token";
          }
        ];
        nginx.virtualHosts."${haName}" = {
          serverName = haName;
          forceSSL = true;
          enableACME = true;
          http3 = true;
          kTLS = true;
          locations = {
            "/" = {
              proxyPass = "http://localhost:${toString haPort}";
              recommendedProxySettings = true;
              proxyWebsockets = true;
            };
          };
        };
      };
      systemd.services.vmagent.serviceConfig.LoadCredential =
        "hass_token:${config.sops.secrets.hass-token.path}";
      users.users.hass.extraGroups = [ "dialout" ];
    };
}
