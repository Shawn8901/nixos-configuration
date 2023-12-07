{ self, self', inputs, lib, config, withSystem, ... }:
let
  inherit (config.shawn8901.system-generator) generateSystem;
  cfg = config.shawn8901.nixosConfigurations;
in {
  config.fp-rndp-lib.nixosConfigurations = {
    cache = {
      hostPlatform.system = "aarch64-linux";
      nixpkgs = inputs.nixpkgs-stable;
      hmInput = inputs.home-manager-stable;
      home-manager.shawn = { };
      disabledModules = [ "services/monitoring/vmagent.nix" ];
      extraModules = [
        inputs.attic.nixosModules.atticd
        (inputs.nixpkgs.outPath
          + "/nixos/modules/services/monitoring/vmagent.nix")

        ../modules/nixos/attic-server
      ];
    };
    next = {
      nixpkgs = inputs.nixpkgs-oldstable;
      disabledModules = [ "services/monitoring/vmagent.nix" ];
      extraModules = [
        (inputs.nixpkgs.outPath
          + "/nixos/modules/services/monitoring/vmagent.nix")
      ];
    };
    pointalpha = {
      nixpkgs = inputs.nixpkgs;
      hmInput = inputs.home-manager;
      unfreeSoftware = [
        "steam"
        "steam-run"
        "steam-original"
        "vscode"
        "vscode-extension-MS-python-vscode-pylance"
        "deezer"
        "discord"
        "teamspeak-client"
        "tampermonkey"
        "betterttv"
        "teamviewer"
        "keymapp"
      ];
      home-manager.shawn = { };
    };
    pointjig = {
      nixpkgs = inputs.nixpkgs-oldstable;
      hmInput = inputs.home-manager-oldstable;
      home-manager.shawn = { };
      extraModules = [
        inputs.simple-nixos-mailserver.nixosModules.default
        inputs.mimir.nixosModules.default
        inputs.stfc-bot.nixosModules.default
        (inputs.nixpkgs.outPath
          + "/nixos/modules/services/monitoring/vmagent.nix")
      ];
      disabledModules = [ "services/monitoring/vmagent.nix" ];
    };
    shelter = {
      nixpkgs = inputs.nixpkgs-stable;
      hmInput = inputs.home-manager-stable;
      home-manager.shawn = { };
      disabledModules = [ "services/monitoring/vmagent.nix" ];
      extraModules = [
        (inputs.nixpkgs.outPath
          + "/nixos/modules/services/monitoring/vmagent.nix")
      ];
    };
    tank = {
      nixpkgs = inputs.nixpkgs;
      hmInput = inputs.home-manager;
      home-manager.shawn = { };
      extraModules = [
        inputs.mimir.nixosModules.default
        inputs.stfc-bot.nixosModules.default
      ];
    };
    zenbook = {
      nixpkgs = inputs.nixpkgs;
      hmInput = inputs.home-manager;
      unfreeSoftware = [
        "steam"
        "steam-run"
        "steam-original"
        "vscode"
        "vscode-extension-MS-python-vscode-pylance"
        "deezer"
        "discord"
        "teamspeak-client"
        "tampermonkey"
        "betterttv"
      ];
      home-manager.shawn = { };
    };
  };

  config.flake.hydraJobs = {
    nixos = lib.mapAttrs (_: cfg: cfg.config.system.build.toplevel)
      config.flake.nixosConfigurations;
  };

}
