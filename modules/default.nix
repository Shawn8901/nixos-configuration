{
  lib,
  ...
}:
let
  dirContents = builtins.readDir ./.;

  validModules = lib.filterAttrs (
    name: type:
    name != "default.nix"
    && (
      (type == "regular" && lib.hasSuffix ".nix" name)
      || (type == "directory" && builtins.pathExists (./. + "/${name}/default.nix"))
    )
  ) dirContents;

  modulePaths = map (name: ./. + "/${name}") (builtins.attrNames validModules);
in
{
  imports = modulePaths;
}
