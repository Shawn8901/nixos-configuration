{ inputs, ... }:
{
  flake-file.inputs.flake-file.url = "github:denful/flake-file";
  flake-file.inputs.den.url = "github:denful/den";
  imports = [
    (inputs.flake-file.flakeModules.dendritic or { })
    (inputs.den.flakeModules.dendritic or { })
  ];
}
