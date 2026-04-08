{ inputs, ... }:
{

  flake-file.inputs.mimir = {
    url = "github:Shawn8901/mimir";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.aspects.pointjig.nixos =
    {
      config,
      inputs',
      ...
    }:
    {
      imports = [
        inputs.mimir.nixosModules.default
      ];

      sops.secrets.mimir-env = {
        owner = "mimir";
        group = "mimir";
      };
      services.stne-mimir = {
        enable = true;
        clientPackage = inputs'.mimir.packages.mimir-client;
        package = inputs'.mimir.packages.mimir;
        envFile = config.sops.secrets.mimir-env.path;
      };
    };
}
