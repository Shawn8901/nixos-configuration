{
  den,
  inputs,
  self,
  ...
}:
{
  debug = true;
  systems = builtins.attrNames den.hosts;
  flake =
    let
      pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
      hydraJob = "merge-pr";
    in
    {
      hydraJobs = {
        ${hydraJob} = pkgs.releaseTools.aggregate {
          name = hydraJob;
          meta = {
            schedulingPriority = 1;
          };
          constituents = map (n: "nixos." + n) (inputs.nixpkgs.lib.attrNames self.nixosConfigurations);
        };

        nixos = inputs.nixpkgs.lib.mapAttrs (
          _: cfg: cfg.config.system.build.toplevel
        ) self.nixosConfigurations;
      };
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = with pkgs; [
          direnv
          nix-direnv
          statix
        ];
      };
    };

  den.hosts = {
    x86_64-linux = {
      next = { };
      pointalpha.users.shawn = { };
      pointjig.users.shawn = { };
      shelter.users.shawn = { };
      tank.users.shawn = { };
      zenbook.users.shawn = { };
    };
    aarch64-linux.watchtower.users.shawn = { };
  };
}
