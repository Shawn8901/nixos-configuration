{
  flake-file.inputs = {
    nixpkgs.url = "github:shawn8901/nixpkgs/nixos-unstable-custom";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

}
