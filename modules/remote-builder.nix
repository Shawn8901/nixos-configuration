{ config, lib, ... }:
let
  cfg = config.includes.remote-builder;
in
{
  options.includes.remote-builder = {
    enable = lib.mkEnableOption "remote builder";
    authorizationFile = lib.mkOption {
      type = lib.types.path;
    };
    settings = lib.mkOption {
      default = { };
    };
  };

  config = lib.mkIf cfg.enable {
    services.hydra-builder = {
      enable = true;
      queueRunnerAddr = "https://queue-runner.hydra.pointjig.de";
      inherit (cfg) authorizationFile settings;
    };
    systemd.services.hydra-builder = {
      after = [ "network-online.target" ];
      requires = [ "network-online.target" ];
    };
  };
}
