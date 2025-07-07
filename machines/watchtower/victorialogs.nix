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

  cfg = config.shawn8901.victorialogs;
in
{
  options = {
    shawn8901.victorialogs = {
      enable = mkEnableOption "Enables a preconfigured victoria logs instance";
      package = mkPackageOption pkgs "victorialogs" { };
      hostname = mkOption {
        type = types.str;
        description = "full qualified hostname of the grafana instance";
      };
      port = mkOption {
        type = types.int;
        default = 9428;
      };
      username = mkOption { type = types.str; };
      credentialsFile = mkOption { type = types.path; };
    };
  };
  config = mkIf cfg.enable {
    services = {
      nginx = {
        enable = mkDefault true;
        recommendedGzipSettings = true;
        recommendedOptimisation = true;
        recommendedTlsSettings = true;
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
      victorialogs = {
        inherit (cfg) package;
        enable = true;
        listenAddress = "localhost:${toString cfg.port}";
        basicAuthUsername = cfg.username;
        basicAuthPasswordFile = cfg.credentialsFile;
      };
    };
  };
}
