{ inputs, ... }:
{
  flake-file.inputs.flake-file.url = "github:vic/flake-file";
  flake-file.inputs.den.url = "github:vic/den";
  imports = [
    (inputs.flake-file.flakeModules.dendritic or { })
    (inputs.den.flakeModules.dendritic or { })
  ];
}
