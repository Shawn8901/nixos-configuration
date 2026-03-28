{ inputs, ... }:
{
  imports = [
    (inputs.den.namespace "cfg" false)
  ];
}
