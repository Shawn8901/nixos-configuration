{
  pkgs,
  lib,
  config,
  ...
}:
let
  inherit (lib)
    types
    mkEnableOption
    mkPackageOption
    mkOption
    mkDefault
    mkIf
    ;

  cfg = config.shawn8901.victoriametrics;
in
{
  options = {
    shawn8901.victoriametrics = {
      enable = mkEnableOption "Enables a preconfigured victoria metrics instance";
      package = mkPackageOption pkgs "victoriametrics" { };
      hostname = mkOption {
        type = types.str;
        description = "full qualified hostname of the grafana instance";
      };
      port = mkOption {
        type = types.int;
        default = 8427;
      };
      username = mkOption { type = types.str; };
      credentialsFile = mkOption { type = types.path; };
      datasources = mkOption { type = types.listOf types.raw; };
    };
  };
  config = mkIf cfg.enable {
    services = {
      nginx = {
        enable = mkDefault true;
        recommendedGzipSettings = true;
        recommendedOptimisation = true;
        recommendedTlsSettings = true;
        recommendedProxySettings = true;
        virtualHosts."${cfg.hostname}" = {
          enableACME = true;
          forceSSL = true;
          http3 = true;
          kTLS = true;
          locations."/" = {
            proxyPass = "http://127.0.0.1:${toString cfg.port}";
            proxyWebsockets = true;
            recommendedProxySettings = true;
          };
        };
      };
      victoriametrics = {
        inherit (cfg) package;
        enable = true;
        retentionPeriod = "1y";
        listenAddress = "localhost:${toString cfg.port}";
        basicAuthUsername = cfg.username;
        basicAuthPasswordFile = cfg.credentialsFile;
        extraOptions = [
          "-selfScrapeInterval=10s"
          "-selfScrapeInstance=${config.networking.hostName}"
        ];
      };
    };
  };
}
