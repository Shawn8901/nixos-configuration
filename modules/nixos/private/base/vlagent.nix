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

  systemd.services.vlagent.before = [
    "systemd-journal-upload.service"
  ];

  services = {
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
  };
}
