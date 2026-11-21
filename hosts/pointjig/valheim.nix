{
  config,
  sources,
  ...
}:
{
  sops.secrets.valheim = {
    owner = "valheim";
    group = "valheim";
  };

  nixpkgs.config.allowUnfreePackages = [
    "steamcmd"
    "steam-unwrapped"
  ];

  imports = [
    "${sources.valheim-nix}/modules"
  ];

  services.valheim = {
    enable = true;
    serverName = "pointjig.de";
    passwordFile = config.sops.secrets.valheim.path;
    worldName = "MPTuT";
    maxPlayers = 5;
    openFirewall = true;
  };
}
