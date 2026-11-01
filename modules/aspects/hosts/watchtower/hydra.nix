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
          cachix-token = {
            owner = "hydra-queue-runner";
            group = "hydra";
            mode = "0660";
          };
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
          "channel.${hostName}" = {
            enableACME = true;
            forceSSL = true;
            http3 = true;
            kTLS = true;
            root = "/var/lib/channels";
            locations = {
              "/nixos-unstable-custom/nixexprs.tar.zst".extraConfig = ''
                include /var/lib/channels/nixos-unstable-custom/current_header.conf;
                add_header Cache-Control "public, max-age=60";
              '';
              "/nixos-unstable-custom/tarballs".extraConfig = ''
                autoindex on;
              '';
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
            merge-pr = pkgs.writeShellScriptBin "merge_pr" ''
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
            channel-update = pkgs.writeShellScriptBin "update-channel" ''
              TARBALL_PATH="$(${lib.getExe pkgs.jq} --raw-output '.outputs[-1].path' $HYDRA_JSON)"
              NAME="$(${lib.getExe pkgs.jq} --raw-output '.products[-1].name' $HYDRA_JSON)"
              NIX_NAME="$(${lib.getExe pkgs.jq} --raw-output '.nixName' $HYDRA_JSON)"
              CHANNEL_DIR="/var/lib/channels/nixos-unstable-custom"
              TARBALLS_DIR="$CHANNEL_DIR/tarballs"
              DEST_PATH="$TARBALLS_DIR/$NAME"

              if [ ! -f "$DEST_PATH" ]; then
                  cp "$TARBALL_PATH/tarballs/$NAME" "$DEST_PATH"
                  chmod 644 "$DEST_PATH"
              fi

              TEMP_DIR=$(mktemp -d)
              trap 'rm -rf "$TEMP_DIR"' EXIT INT TERM

              tar -xf "$DEST_PATH" -C "$TEMP_DIR" --strip-components=1

              NAR_HASH=$(nix hash path "$TEMP_DIR")
              LAST_MODIFIED=$(stat -c %Y $DEST_PATH)
              PUBLIC_URL="https://channel.hydra.pointjig.de/nixos-unstable-custom/tarballs/$NAME?narHash=$NAR_HASH&lastModified=$LAST_MODIFIED"

              cat <<EOF > "$CHANNEL_DIR/current_header.conf"
              add_header Link '<$PUBLIC_URL>; rel="immutable"';
              EOF

              /run/wrappers/bin/sudo /run/current-system/sw/bin/systemctl reload nginx

              echo "Bumped channel to $NAME"
            '';
            push-stdenv = pkgs.writeShellScriptBin "update-channel" ''
              output_paths=$(${lib.getExe pkgs.jq} --raw-output '.outputs[-1].path' $HYDRA_JSON)
              echo "Pushing outputs ''${output_paths} to cachix"

              CACHIX_AUTH_TOKEN="$(<"${config.sops.secrets.cachix-token.path}")"
              export CACHIX_AUTH_TOKEN
              ${lib.getExe pkgs.cachix} push x86-64-v3 "''${output_paths}"
            '';
          in
          {
            enable = true;
            listenHost = "127.0.0.1";
            port = 3001;
            package = pkgs.hydra;
            notificationSender = mailAdress;
            minimumDiskFree = 10;
            minimumDiskFreeEvaluator = 15;
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
              evaluator_max_memory_size = ${toString (6 * 1024)}
              <runcommand>
                job = *:*:merge-pr
                command = ${lib.getExe merge-pr}
              </runcommand>
              <runcommand>
                job = *:*:channel
                command = ${lib.getExe channel-update}
              </runcommand>
              <runcommand>
                job = x86-64-v3:stdenv:*
                command = ${lib.getExe push-stdenv}
              </runcommand>
              <hydra_notify>
                <prometheus>
                  listen_address = 127.0.0.1
                  port = 9199
                </prometheus>
              </hydra_notify>
              <git-input>
                timeout = 3600
              </git-input>
              <githubstatus>
                jobs = .*
                useShortContext = true
                excludeBuildFromContext = true
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

      security.sudo.extraRules = [
        {
          users = [ "hydra-queue-runner" ];
          commands = [
            {
              command = "/run/current-system/sw/bin/systemctl reload nginx";
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ];

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
              "git+https://gitlab.com/rycee/nur-expressions/"
              "github:Shawn8901/"
              "https://github.com/"
              "https://gitlab.com/"
              "git+https://gitlab.com/"
              "https://channel.hydra.pointjig.de"
            ];
          in
          ''
            extra-allowed-uris = ${lib.concatStringsSep " " urls}
          '';
      };
    };
}
