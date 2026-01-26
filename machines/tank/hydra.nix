{
  self,
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.shawn8901.hydra;
  hosts = self.nixosConfigurations;

  inherit (lib)
    mkEnableOption
    mkPackageOption
    mkOption
    mkDefault
    types
    ;
in
{
  options = {
    shawn8901.hydra = {
      enable = mkEnableOption "Enables a preconfigured hydra instance";
      hostName = mkOption {
        type = types.str;
        description = "Hostname of the hydra instance";
      };
      mailAdress = mkOption {
        type = types.str;
        description = "Adress to send notifications to";
      };
      writeTokenFile = mkOption { type = types.path; };
      writeTokenIncludeFile = mkOption { type = types.path; };
      githubHookIncludeFile = mkOption { type = types.path; };
      attic = {
        enable = mkEnableOption "Enables usage of attic as binary cache";
        package = mkPackageOption pkgs "attic-client" { };
        configFile = mkOption { type = types.path; };
      };
      builder = {
        sshKeyFile = mkOption { type = types.path; };
        userName = mkOption {
          type = types.str;
          default = config.shawn8901.remote-builder.userName;
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall = {
      allowedUDPPorts = [ 443 ];
      allowedTCPPorts = [
        80
        443
      ];
    };

    systemd.tmpfiles.rules = lib.mkMerge [
      [ "f /tmp/hyda/dynamic-machines 666 hydra hydra - " ]
      (lib.optionals cfg.attic.enable [ "d /var/lib/attic 666 attic attic -" ])
    ];

    services = {
      nginx = {
        enable = mkDefault true;
        recommendedGzipSettings = true;
        recommendedOptimisation = true;
        recommendedTlsSettings = true;
        recommendedProxySettings = true;
        virtualHosts."${cfg.hostName}" = {
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
        enable = mkDefault true;
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
            -H "Authorization: Bearer $(<${cfg.writeTokenFile})" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            https://api.github.com/repos/shawn8901/nixos-configuration/pulls/$job_name/merge \
            -d '{"merge_method":"rebase"}'
          '';
        in
        {
          enable = true;
          listenHost = "127.0.0.1";
          port = 3000;
          package = pkgs.hydra;
          notificationSender = cfg.mailAdress;
          buildMachinesFiles = [
            "/etc/nix/machines"
            "/tmp/hyda/dynamic-machines"
          ];
          minimumDiskFree = 25;
          minimumDiskFreeEvaluator = 50;
          hydraURL = "https://${cfg.hostName}";
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
          ''
          + lib.optionalString (cfg.writeTokenIncludeFile != null) ''
            Include ${cfg.writeTokenIncludeFile}
          ''
          + lib.optionalString (cfg.githubHookIncludeFile != null) ''
            Include ${cfg.githubHookIncludeFile}
          '';
        };
    };

    systemd.services = (
      lib.optionalAttrs cfg.attic.enable {
        attic-watch-store = {
          wantedBy = [ "multi-user.target" ];
          after = [ "network-online.target" ];
          requires = [ "network-online.target" ];
          description = "Upload all store content to binary catch";
          serviceConfig = {
            User = "attic";
            Restart = "always";
            ExecStart = "${cfg.attic.package}/bin/attic watch-store nixos";
          };
        };
      }
    );

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
          sshUser = cfg.builder.userName;
          sshKey = cfg.builder.sshKeyFile;
        }
      ];
      settings = {
        keep-outputs = mkDefault true;
        keep-derivations = mkDefault true;
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

    users.users = lib.mkIf (cfg.attic.enable) {
      attic = {
        isNormalUser = false;
        isSystemUser = true;
        group = "users";
        home = "/var/lib/attic";
      };
    };
  };
}
