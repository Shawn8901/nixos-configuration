{
  system ? builtins.currentSystem,
  pinUpdate ? false,
}:
let
  sources = import ../lon.nix;
  systems = import ../system.nix;
  lib = import "${sources.nixpkgs}/lib";
  pkgs = import sources.nixpkgs { inherit system; };
in
{
  nixos = lib.mapAttrs (name: attr: attr.config.system.build.toplevel) systems;
}
// lib.optionalAttrs pinUpdate {
  merge-pr = pkgs.releaseTools.aggregate {
    name = "merge-pr";
    meta.schedulingPriority = 1;
    constituents = map (n: "nixos." + n) (builtins.attrNames systems);
  };
}
