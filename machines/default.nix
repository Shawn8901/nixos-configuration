{
  inputs,
  lib,
  config,
  ...
}:
{
  config.fp-lib.nixosConfigurations = {
    watchtower = {
      hostPlatform.system = "aarch64-linux";
      nixpkgs = inputs.nixpkgs;
      home-manager = {
        input = inputs.home-manager;
        users = [ "shawn" ];
      };
      extraModules = [
        inputs.disko.nixosModules.disko
        ./watchtower/attic-server.nix
        ./watchtower/victoriametrics.nix
        ./watchtower/victorialogs.nix
        ./watchtower/grafana.nix
      ];
    };
    next = {
      nixpkgs = inputs.nixpkgs-stable;
    };
    pointalpha = {
      inherit (inputs) nixpkgs;
      home-manager = {
        input = inputs.home-manager;
        users = [ "shawn" ];
      };
    };
    pointjig = {
      nixpkgs = inputs.nixpkgs-stable;
      home-manager = {
        input = inputs.home-manager-stable;
        users = [ "shawn" ];
      };
      extraModules = [
        inputs.mimir.nixosModules.default
        inputs.stfc-bot.nixosModules.default
      ];
    };
    shelter = {
      nixpkgs = inputs.nixpkgs-stable;
      home-manager = {
        input = inputs.home-manager-stable;
        users = [ "shawn" ];
      };
      extraModules = [ inputs.disko.nixosModules.disko ];
    };
    tank = {
      inherit (inputs) nixpkgs;
      home-manager = {
        input = inputs.home-manager;
        users = [ "shawn" ];
      };
      extraModules = [
        inputs.mimir.nixosModules.default
        inputs.stfc-bot.nixosModules.default
        ./tank/hydra.nix
      ];
    };
    zenbook = {
      nixpkgs = inputs.nixpkgs-stable;
      home-manager = {
        input = inputs.home-manager-stable;
        users = [ "shawn" ];
      };
      extraModules = [
        inputs.asus-numberpad-driver.nixosModules.default
      ];
    };
  };

  config.flake.hydraJobs = {
    nixos = lib.mapAttrs (_: cfg: cfg.config.system.build.toplevel) config.flake.nixosConfigurations;
  };
}
