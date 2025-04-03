{
  inputs',
  config,
  lib,
  ...
}:
let

  unoptimized = inputs'.nixpkgs.legacyPackages;
  inherit (lib) mkEnableOption mkMerge mkIf;

  cfg = config.shawn8901.optimized;
in
{
  options = {
    shawn8901.optimized = {
      enable = mkEnableOption "use optimized x86-64_v3";
      setup = mkEnableOption "enable that once to make nix aware that it is able to build gcc.arch, passing --option does not work";
      excludeBigPackages = mkEnableOption "Exclude some big packages from optimized builds";
    };

  };
  config = mkMerge [
    (mkIf cfg.setup {
      # In case someone comes around, please be aware that the system feature "gccarch-x86-64-v3"
      # has to be available on the builder before it can build for x86-64_v3
      # can be disabled again after the first initial build as nixpkgs.hostPlatform.gcc.arch implies setting nix system-features
      nix.settings.system-features = [
        "gccarch-x86-64-v3"
        "benchmark"
        "big-parallel"
        "kvm"
        "nixos-test"
      ];
    })
    (mkIf cfg.enable {
      nixpkgs.hostPlatform.gcc.arch = "x86-64-v3";
    })
    (mkIf (cfg.enable && cfg.excludeBigPackages) {
      nixpkgs.config.packageOverrides = pkgs: {
        inherit (unoptimized) openexr_3;
        haskellPackages = pkgs.haskellPackages.override {
          overrides = haskellPackagesNew: haskellPackagesOld: {
            inherit (unoptimized.haskellPackages) cryptonite hermes-json hermes-json_0_2_0_1;
          };
        };

        inherit (unoptimized) portfolio libreoffice-qt krita;
      };
    })
  ];
}
