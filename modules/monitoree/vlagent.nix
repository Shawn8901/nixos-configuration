{ config, lib, ... }:
{
  options.includes.monitoree.vlagent.enable = lib.mkEnableOption "Enables vlagent monitoree";

  config = lib.mkIf (config.includes.monitoree.vlagent.enable) {

    sops.secrets.vlagent.sopsFile = ./secrets.yaml;
    systemd.services.vlagent.before = [ "systemd-journal-upload.service" ];
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
          Upload.URL = "http://127.0.0.1:9429/insert/journald";
        };
      };
    };
  };
}
