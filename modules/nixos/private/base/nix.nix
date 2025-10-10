{
  pkgs,
  lib,
  config,
  ...
}:
let
  inherit (lib)
    mkDefault
    mkForce
    ;
in
{
  sops.secrets = {
    nix-gh-token-ro = {
      sopsFile = ../../../../files/secrets-base.yaml;
      group = config.users.groups.nixbld.name;
      mode = "0444";
    };
    nix-netrc-ro = {
      sopsFile = ../../../../files/secrets-base.yaml;
      group = config.users.groups.nixbld.name;
      mode = "0444";
    };
  };

  nix = {
    channel.enable = false;
    package = pkgs.nix;
    settings = {
      auto-optimise-store = true;
      allow-import-from-derivation = false;
      substituters = [
        "https://cache.pointjig.de/nixos"
        "https://shawn8901.cachix.org"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "nixos:m4zyjiPgXOAWJZ/qVawVuOvPCmrSOfagQc/zbaDmq2Q="
        "shawn8901.cachix.org-1:XNCe1k4O+gQbithVgUERo6b/B5UtgKU689b0VbKnfDc="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
      cores = mkDefault 4;
      max-jobs = mkDefault 1;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      netrc-file = mkForce config.sops.secrets.nix-netrc-ro.path;
    };
    extraOptions = ''
      !include ${config.sops.secrets.nix-gh-token-ro.path}
      min-free = ${toString (1024 * 1024 * 1024)}
      max-free = ${toString (5 * 1024 * 1024 * 1024)}
    '';
    nrBuildUsers = mkForce 16;
    daemonIOSchedClass = "idle";
    daemonCPUSchedPolicy = "idle";
  };

  programs.nh = {
    enable = true;
    flake = lib.mkDefault "github:shawn8901/nixos-configuration";
    clean = {
      enable = true;
      dates = "daily";
      extraArgs = lib.mkDefault "--keep 5 --keep-since 7d";
    };
  };
}
