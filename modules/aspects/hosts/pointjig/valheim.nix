{ inputs, den, ... }:
{

  flake-file.inputs.valheim = {
    url = "github:shawn8901/valheim-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.aspects.pointjig = {
    includes = [
      (den.provides.unfree [
        "steamcmd"
        "steam-unwrapped"
      ])
    ];

    nixos =
      {
        config,
        inputs',
        ...
      }:
      {

        sops.secrets.valheim = {
          owner = "valheim";
          group = "valheim";
        };

        imports = [
          inputs.valheim.nixosModules.default
        ];

        services.valheim = {
          enable = true;
          serverName = "pointjig.de";
          passwordFile = config.sops.secrets.valheim.path;
          worldName = "MPTuT";
          maxPlayers = 5;
          openFirewall = true;
        };
      };
  };
}
