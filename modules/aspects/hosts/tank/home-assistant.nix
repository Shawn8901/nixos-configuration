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
            rest = [
              {
                resource = "https://www.heizoel24.de/DailyPriceXml.ashx?zipCode=47239&litre=2000&unloadingpoints=1";
                headers = {
                  user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:124.0) Gecko/20100101 Firefox/124.0";
                };
                scan_interval = 3600;
                sensor = [
                  {
                    name = "heizoelpreis";
                    value_template = "{{ value_json['result']['deliveries']['delivery']['price'][0]['#text'] | regex_replace(find=',' , replace='.') | float }}";
                    unit_of_measurement = "EUR";
                    state_class = "total";
                    device_class = "monetary";
                    unique_id = "heizoelpreis";
                  }
                ];
              }
            ];
          };
          extraPackages =
            python3Packages: with python3Packages; [
              gtts
              pychromecast
              pyipp
            ];
          customLovelaceModules = [
            pkgs.home-assistant-custom-lovelace-modules.xiaomi-vacuum-map-card
          ];
          customComponents = [
            (pkgs.buildHomeAssistantComponent {
              owner = "Sdahl1234";
              domain = "intex_wa510";
              version = "0.6.3-unstable-2026-06-22";

              src = pkgs.fetchFromGitHub {
                owner = "Sdahl1234";
                repo = "intex_wa510";
                rev = "d2b4efdd5ecf6d9b5c29a2212aed4cb41f0b35a8";
                hash = "sha256-VCNUrHdF6eLl2iJ8iodOkFJM1J1x2IlFZAjQTm1kc0k=";
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
            scrape_interval = "5s";
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
