{
  lib,
  withSystem,
  ...
}:
{
  perSystem =
    { pkgs, system, ... }:
    let
      packages = {
        pg-upgrade = pkgs.callPackage ./pg-upgrade { };
        generate-zrepl-ssl = pkgs.callPackage ./shellscripts/generate-zrepl-ssl.nix { };
        # TODO Drop
        victoriametrics-metrics-datasource = lib.warn "you use shawn8901s victoriametrics-metrics-datasource which is deprecated. There is a nixpkgs PR for a signed version. see https://github.com/NixOS/nixpkgs/pull/377809." pkgs.grafanaPlugins.victoriametrics-metrics-datasource;
      };
    in
    {
      inherit packages;
      hydraJobs = packages;
    };

  flake = withSystem "x86_64-linux" (
    { system, pkgs, ... }:
    let
      packages = {
        rtc-helper = pkgs.callPackage ./shellscripts/rtc-helper.nix { };
        nas = pkgs.callPackage ./shellscripts/nas.nix { };
        backup-usb = pkgs.callPackage ./shellscripts/backup-usb.nix { };

        # s25rttr = pkgs.callPackage ./s25rttr {
        #   SDL2 = pkgs.SDL2.override { withStatic = true; };
        # };

        asus-touchpad-numpad-driver = pkgs.python3.pkgs.callPackage ./asus-touchpad-numpad-driver { };

        jameica-fhs = pkgs.callPackage ./jameica/fhsenv.nix { };
      };
    in
    {
      packages."${system}" = packages;
      hydraJobs."${system}" = packages;
    }
  );
}
