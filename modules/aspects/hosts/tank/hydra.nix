{ self, ... }:
{
  den.aspects.tank.nixos =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      hosts = self.nixosConfigurations;

      hostName = "hydra.pointjig.de";
      mailAdress = "hydra@pointjig.de";
      githubHookIncludeFile = config.sops.templates."hydra-hook-token.conf".path;
      writeTokenIncludeFile = config.sops.templates."hydra-write-token.conf".path;
      writeTokenFile = config.sops.secrets.hydra-github-auth.path;
      builder = {
        userName = "builder";
        sshKeyFile = config.sops.secrets.ssh-builder-key.path;
      };
    in
    {
      sops = {
        secrets = {
          ssh-builder-key = {
            owner = "hydra-queue-runner";
          };
          hydra-github-hook = { };
          hydra-github-auth = {
            owner = "hydra-queue-runner";
            group = "hydra";
          };
          attic-token = { };
        };
        templates = {
          "hydra-write-token.conf" = {
            content = ''
              <github_authorization>
                Shawn8901 = Bearer ${config.sops.placeholder.hydra-github-auth}
              </github_authorization>
            '';
            owner = "hydra-queue-runner";
            group = "hydra";
            mode = "0660";
          };
          "hydra-hook-token.conf" = {
            content = ''
              <github>
                secret = ${config.sops.placeholder.hydra-github-hook}
              </github>
            '';
            owner = "hydra-www";
            group = "hydra";
            mode = "0660";
          };
          "attic-config" = {
            content = ''
              default-server = "nixos"
              [servers.nixos]
              endpoint = "https://cache.pointjig.de"
              token = "${config.sops.placeholder.attic-token}"
            '';
            owner = "attic";
            mode = "0600";
            path = "/var/lib/attic/.config/attic/config.toml";
          };
        };
      };

      networking.firewall = {
        allowedUDPPorts = [ 443 ];
        allowedTCPPorts = [
          80
          443
        ];
      };

      systemd = {
        tmpfiles.rules = [
          "f /tmp/hyda/dynamic-machines 666 hydra hydra - "
          "d /var/lib/attic 700 attic - -"
        ];
        services.pointalpha-online =
          let
            systemFeatures = hosts.pointalpha.config.nix.settings.system-features;
            jobs = hosts.pointalpha.config.nix.settings.max-jobs;
            speedFactor = 1;
          in
          {
            script = ''
              if ${pkgs.iputils}/bin/ping -c1 -w 1 pointalpha > /dev/null; then
                if ! grep pointalpha /tmp/hyda/dynamic-machines > /dev/null; then
                  echo "ssh://root@pointalpha x86_64-linux,i686-linux ${config.sops.secrets.ssh-builder-key.path} ${toString jobs} ${toString speedFactor} ${lib.concatStringsSep "," systemFeatures} - -" >  /tmp/hyda/dynamic-machines
                  echo "Added pointalpha to dynamic build machines"
                fi
              else
                if grep pointalpha /tmp/hyda/dynamic-machines > /dev/null; then
                  echo "" > /tmp/hyda/dynamic-machines
                  echo "Cleared dynamic build machines"
                fi
              fi
            '';
          };
        timers.pointalpha-online = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "*:0/1";
          };
        };
      };
      services = {
        nginx = {
          enable = true;
          recommendedGzipSettings = true;
          recommendedOptimisation = true;
          recommendedTlsSettings = true;
          recommendedProxySettings = true;
          virtualHosts."${hostName}" = {
            enableACME = true;
            forceSSL = true;
            http3 = true;
            kTLS = true;
            locations."/" = {
              proxyPass = "http://${config.services.hydra.listenHost}:${toString config.services.hydra.port}";
              recommendedProxySettings = true;
            };
          };
        };
        postgresql = {
          enable = true;
          ensureDatabases = [ "hydra" ];
          ensureUsers = [
            {
              name = "hydra";
              ensureDBOwnership = true;
            }
          ];
        };
        vmagent.prometheusConfig.scrape_configs = [
          {
            job_name = "hydra_notify";
            static_configs = [ { targets = [ "localhost:9199" ]; } ];
          }
        ];

        hydra =
          let
            jq = lib.getExe pkgs.jq;
            merge_pr = pkgs.writeScriptBin "merge_pr" ''
              cat $HYDRA_JSON
              echo ""
              job_name=$(${jq} --raw-output ".jobset" $HYDRA_JSON)
              buildStatus=$(${jq} ".buildStatus" $HYDRA_JSON)
              if [[ "$job_name" = "main" ]]; then
                echo "Job $job_name is not a PR but the main branch."
                exit 0
              fi

              if [[ $buildStatus != 0 ]]; then
                echo "Build was not successful. Do not merge."
                exit 1
              fi

              echo ""
              echo "Job $job_name is a PR merge back to main branch."
              echo ""
              ${lib.getExe pkgs.curl} -L \
              -X PUT \
              -H "Accept: application/vnd.github+json" \
              -H "Authorization: Bearer $(<${writeTokenFile})" \
              -H "X-GitHub-Api-Version: 2022-11-28" \
              https://api.github.com/repos/shawn8901/nixos-configuration/pulls/$job_name/merge \
              -d '{"merge_method":"rebase"}'
            '';
          in
          {
            enable = true;
            listenHost = "127.0.0.1";
            port = 3001;
            package = pkgs.hydra;
            notificationSender = mailAdress;
            buildMachinesFiles = [
              "/etc/nix/machines"
              "/tmp/hyda/dynamic-machines"
            ];
            minimumDiskFree = 25;
            minimumDiskFreeEvaluator = 50;
            hydraURL = "https://${hostName}";
            useSubstitutes = true;
            extraConfig = ''
              evaluator_max_memory_size = ${toString (4 * 1024)}
              evaluator_workers = 4
              max_concurrent_evals = 1
              restrict-eval = false
              max_output_size = ${toString (5 * 1024 * 1024 * 1024)}
              max_db_connections = 150
              compress_build_logs = 1
              <runcommand>
                job = *:*:merge-pr
                command = ${lib.getExe merge_pr}
              </runcommand>
              <hydra_notify>
                <prometheus>
                  listen_address = 127.0.0.1
                  port = 9199
                </prometheus>
              </hydra_notify>
              <githubstatus>
                jobs = .*
                useShortContext = true
              </githubstatus>
              Include ${writeTokenIncludeFile}
              Include ${githubHookIncludeFile}
            '';
          };
      };

      systemd.services.attic-watch-store = {
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        requires = [ "network-online.target" ];
        description = "Upload all store content to binary catch";
        serviceConfig = {
          User = "attic";
          Restart = "always";
          ExecStart = "${lib.getExe pkgs.attic-client} watch-store nixos";
        };
      };

      programs.ssh.extraConfig = ''
        Host watchtower
        Hostname watchtower.pointjig.de
        Port 2242
        Compression yes
      '';

      nix = {
        package = lib.mkForce pkgs.hydra.nix;
        buildMachines = [
          {
            hostName = "localhost";
            protocol = null;
            systems = [
              "x86_64-linux"
              "i686-linux"
            ];
            supportedFeatures = config.nix.settings.system-features ++ [
              "gccarch-x86-64-v3"
            ];
            maxJobs = 4;
          }
          {
            hostName = "watchtower";
            systems = [ "aarch64-linux" ];
            maxJobs = 1;
            supportedFeatures = hosts.watchtower.config.nix.settings.system-features;
            sshUser = builder.userName;
            sshKey = builder.sshKeyFile;
          }
        ];
        settings = {
          keep-outputs = true;
          keep-derivations = true;
        };
        extraOptions =
          let
            urls = [
              "https://gitlab.com/api/v4/projects/rycee%2Fnmd"
              "https://git.sr.ht/~rycee/nmd"
              "https://github.com/zhaofengli/"
              "git+https://github.com/zhaofengli/"
              "github:NixOS/"
              "github:nix-community/"
              "github:numtide/flake-utils"
              "github:hercules-ci/flake-parts"
              "github:nix-systems/default/"
              "github:Mic92/sops-nix/"
              "github:zhaofengli/"
              "github:ipetkov/crane/"
              "gitlab:rycee/nur-expressions/"
              "github:Shawn8901/"
            ];
          in
          ''
            extra-allowed-uris = ${lib.concatStringsSep " " urls}
          '';
      };

      users.users.attic = {
        isNormalUser = false;
        isSystemUser = true;
        group = "users";
        home = "/var/lib/attic";
      };
    };
}
