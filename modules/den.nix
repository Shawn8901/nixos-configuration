{
  den,
  inputs,
  self,
  ...
}:
{
  debug = true;

  systems = builtins.attrNames den.hosts;

  flake = {
    hydraJobs =
      let
        name = "merge-pr";
      in
      {
        ${name} = inputs.nixpkgs.legacyPackages.x86_64-linux.releaseTools.aggregate {
          inherit name;
          meta = {
            schedulingPriority = 1;
          };
          constituents = map (n: "nixos." + n) (inputs.nixpkgs.lib.attrNames self.nixosConfigurations);
        };

        nixos = inputs.nixpkgs.lib.mapAttrs (
          _: cfg: cfg.config.system.build.toplevel
        ) self.nixosConfigurations;
      };
    devShells.x86_64-linux.default =
      let
        pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
      in
      pkgs.mkShell {
        packages = with pkgs; [
          direnv
          nix-direnv
          statix
        ];
      };
  };

  den.hosts = {
    x86_64-linux = {
      next.instantiate = inputs.nixpkgs-stable.lib.nixosSystem;
      pointalpha.users.shawn = { };
      pointjig = {
        instantiate = inputs.nixpkgs-stable.lib.nixosSystem;
        home-manager.module = inputs.home-manager-stable.nixosModules.home-manager;
        users.shawn = { };
      };
      shelter = {
        instantiate = inputs.nixpkgs-stable.lib.nixosSystem;
        home-manager.module = inputs.home-manager-stable.nixosModules.home-manager;
        users.shawn = { };
      };
      tank.users.shawn = { };
      zenbook = {
        instantiate = inputs.nixpkgs-stable.lib.nixosSystem;
        home-manager.module = inputs.home-manager-stable.nixosModules.home-manager;
        users.shawn = { };
      };
    };
    aarch64-linux.watchtower = {
      instantiate = inputs.nixpkgs.lib.nixosSystem;
      home-manager.module = inputs.home-manager.nixosModules.home-manager;
      users.shawn = { };
    };
  };
}
