{
  den.aspects.watchtower.nixos =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      hostName = "hydra.pointjig.de";
      mailAdress = "hydra@pointjig.de";
      writeTokenIncludeFile = config.sops.templates."hydra-write-token.conf".path;
      writeTokenFile = config.sops.secrets.hydra-github-auth.path;
    in
    {
      sops = {
        secrets = {
          hydra-github-auth = {
            owner = "hydra-queue-runner";
            group = "hydra";
          };
          local-queue-runner-token = {
            mode = "0440";
            group = "hydra";
          };
          pointalpha-queue-runner-token.owner = "hydra-queue-runner";
          tank-queue-runner-token.owner = "hydra-queue-runner";
        };
        templates."hydra-write-token.conf" = {
          content = ''
            <github_authorization>
              shawn8901 = Bearer ${config.sops.placeholder.hydra-github-auth}
            </github_authorization>
          '';
          owner = "hydra-queue-runner";
          group = "hydra";
          mode = "0660";
        };
      };

      # We dont build fully perlless yet
      system.forbiddenDependenciesRegexes = lib.mkForce [ ];

      networking.firewall = {
        allowedUDPPorts = [ 443 ];
        allowedTCPPorts = [
          80
          443
        ];
      };

      services = {
        nginx.virtualHosts = {
          "${hostName}" = {
            enableACME = true;
            forceSSL = true;
            http3 = true;
            kTLS = true;
            locations."/" = {
              proxyPass = "http://${config.services.hydra.listenHost}:${toString config.services.hydra.port}";
              recommendedProxySettings = true;
            };
          };
          "queue-runner.${hostName}" = {
            enableACME = true;
            forceSSL = true;
            locations."/".extraConfig = ''
              # This is necessary so that grpc connections do not get closed early
              # see https://stackoverflow.com/a/67805465
              client_body_timeout 31536000s;
              client_max_body_size 0;

              grpc_pass grpc://${config.services.hydra.queueRunner.grpc.address}:${toString config.services.hydra.queueRunner.grpc.port};

              grpc_read_timeout 31536000s; # 1 year in seconds
              grpc_send_timeout 31536000s; # 1 year in seconds
              grpc_socket_keepalive on;

              # Builders reuse one long-lived HTTP/2 channel for many RPCs. The
              # default keepalive_requests (1000) makes nginx GOAWAY mid-stream,
              # cancelling in-flight RPCs and aborting builds.
              keepalive_requests 1000000;
              keepalive_timeout 600s;

              grpc_set_header Host $host;
              grpc_set_header X-Real-IP $remote_addr;
              grpc_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              grpc_set_header X-Forwarded-Proto $scheme;
            '';
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
            minimumDiskFree = 25;
            minimumDiskFreeEvaluator = 50;
            hydraURL = "https://${hostName}";
            useSubstitutes = true;
            queueRunner.settings = {
              maxOutputSize = (5 * 1024 * 1024 * 1024);
              maxUnsupportedTimeInS = (48 * 60 * 60);
              tokenPaths = with config.sops.secrets; [
                local-queue-runner-token.path
                pointalpha-queue-runner-token.path
                tank-queue-runner-token.path
              ];
            };
            evaluatorSettings.max_concurrent_evals = 1;
            extraConfig = ''
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
            '';
          };
        hydra-builder = {
          enable = true;
          queueRunnerAddr = "https://queue-runner.${hostName}";
          authorizationFile = config.sops.secrets.local-queue-runner-token.path;
        };
      };

      nix = {
        package = lib.mkForce pkgs.hydra.nix;
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
    };
}
