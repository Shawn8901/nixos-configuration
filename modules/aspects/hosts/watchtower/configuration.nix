{ cfg, ... }:
{
  den.aspects.watchtower.provides.to-users = {
    includes = [
      cfg.monitoree
      cfg.server
      cfg.postgresql
    ];

    nixos =
      {
        config,
        pkgs,
        modulesPath,
        ...
      }:
      {

        imports = [
          "${modulesPath}/profiles/headless.nix"
          "${modulesPath}/profiles/perlless.nix"
        ];
        sops.defaultSopsFile = ./secrets.yaml;

        networking = {
          nameservers = [
            "208.67.222.222"
            "208.67.220.220"
          ];
          domain = "";
          useDHCP = true;
        };
        systemd.network.wait-online.anyInterface = true;

        services = {
          openssh.hostKeys = [
            {
              path = "/static/etc/ssh/ssh_host_ed25519_key";
              type = "ed25519";
            }
            {
              path = "/static/etc/ssh/ssh_host_rsa_key";
              type = "rsa";
              bits = 4096;
            }
          ];
          nginx = {
            enable = true;
            package = pkgs.nginx;
            recommendedGzipSettings = true;
            recommendedOptimisation = true;
            recommendedTlsSettings = true;
            recommendedProxySettings = true;
          };
          vmagent = {
            package = pkgs.victoriametrics;
            remoteWrite.url = "http://${config.services.victoriametrics.listenAddress}/api/v1/write";
            prometheusConfig.scrape_configs = [
              {
                job_name = "blackbox_exporter";
                static_configs = [
                  {
                    targets = [ "localhost:${toString config.services.prometheus.exporters.blackbox.port}" ];
                  }
                ];
              }
            ];
          };
          prometheus = {
            enable = true;
            exporters.blackbox = {
              enable = true;
              listenAddress = "localhost";
              configFile = (pkgs.formats.yaml { }).generate "config.yml" {
                modules = {
                  http_2xx = {
                    prober = "http";
                    http = {
                      preferred_ip_protocol = "ip4";
                    };
                  };
                };
              };
            };
          };
          postgresql.package = pkgs.postgresql_16;
        };

        users.users.root.openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMguHbKev03NMawY9MX6MEhRhd6+h2a/aPIOorgfB5oM"
        ];
      };
  };
}
