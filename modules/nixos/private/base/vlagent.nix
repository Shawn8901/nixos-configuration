{
  config,
  lib,
  ...
}:
{
  sops.secrets = {
    vlagent = {
      sopsFile = ../../../../files/secrets-base.yaml;
    };
  };

  services = lib.mkMerge [
    (lib.optionalAttrs (!lib.versionOlder config.system.nixos.release "25.11") {
      vlagent = {
        enable = true;
        remoteWrite = {
          url = lib.mkDefault "https://vl.pointjig.de/internal/insert";
          basicAuthUsername = "vl";
          basicAuthPasswordFile = config.sops.secrets.vlagent.path;
        };
      };
      journald.upload = {
        enable = true;
        settings = {
          Upload.URL = "http://localhost:9429/insert/journald";
        };
      };
    })
  ];
}
