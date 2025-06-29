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
      nginxPrivCertFile = mkOption { type = types.path; };
      nginxPubCertFile = mkOption { type = types.path; };
      caPubCertFile = mkOption { type = types.path; };
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
          enableACME = false;
          forceSSL = true;
          http3 = true;
          kTLS = true;
          sslCertificate = cfg.nginxPubCertFile;
          sslCertificateKey = cfg.nginxPrivCertFile;
          locations."/" = {
            proxyPass = "http://127.0.0.1:${toString cfg.port}";
            proxyWebsockets = true;
            recommendedProxySettings = true;
          };
          extraConfig = ''
            ssl_client_certificate ${cfg.caPubCertFile}
            ssl_verify_client on;
          '';
        };
      };
      victorialogs = {
        inherit (cfg) package;
        enable = true;
        listenAddress = "localhost:${toString cfg.port}";
        extraOptions = [
          "-httpAuth.username=${cfg.username}"
          "-httpAuth.password=file:///${cfg.credentialsFile}"
        ];
      };
    };
  };
}
