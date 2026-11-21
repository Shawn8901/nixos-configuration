let
  sources = import ./lon.nix;
  nixosSystem = import "${sources.nixpkgs}/nixos/lib/eval-config.nix";
  lib = import "${sources.nixpkgs}/lib";
  mkSystem =
    hostname:
    lib.attrsets.genAttrs [ hostname ] (
      hostname:
      nixosSystem {
        specialArgs = { inherit sources; };
        modules = [
          { networking.hostName = hostname; }
          ./modules
          ./hosts/${hostname}/configuration.nix
          "${sources.sops-nix}/modules/sops"
        ];
      }
    );
in
lib.mergeAttrsList [
  (mkSystem "beacon")
  (mkSystem "pointalpha")
  (mkSystem "pointjig")
  (mkSystem "shelter")
  (mkSystem "tank")
  (mkSystem "watchtower")
  (mkSystem "zenbook")
]
