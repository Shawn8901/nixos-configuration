{ pkgs, inputs, ... }:
let
  system = pkgs.hostPlatform.system;
in
{
  environment.systemPackages = with pkgs; [
    nvd
    git
    jq
    wget
    fzf
    gnumake
    tree
    htop
    nano
    unzip
    ncdu
    graphviz
    nix-du
    inputs.agenix.defaultPackage.${system}
  ];
}
