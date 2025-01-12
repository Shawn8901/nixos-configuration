{
  lib,
  withSystem,
  inputs,
  ...
}:
let
  inherit (builtins) elem;

  overrideMesa =
    package:
    (package.overrideAttrs (oldAttrs: {
      env.NIX_CFLAGS_COMPILE = toString [
        "-march=x86-64-v3"
      ];
    })).override
      {
        galliumDrivers = [
          "radeonsi"
          "llvmpipe"
          "svga"
          "d3d12"
        ];
        vulkanDrivers = [
          "amd"
          "microsoft-experimental"
        ];
      };

in
{
  perSystem =
    { pkgs, system, ... }:
    let
      packages = {
        pg-upgrade = pkgs.callPackage ./pg-upgrade { };
        generate-zrepl-ssl = pkgs.callPackage ./shellscripts/generate-zrepl-ssl.nix { };
        vm-grafana-datasource = pkgs.callPackage ./vm-grafana-datasource { };
      };
    in
    {
      inherit packages;
      hydraJobs = packages;
    };

  flake = withSystem "x86_64-linux" (
    { system, pkgs, ... }:
    let
      pkgsDeezer = import inputs.nixpkgs-deezer {
        inherit system;
        config.allowUnfreePredicate = pkg: elem (lib.getName pkg) [ "deezer" ];
        config.permittedInsecurePackages = [ "electron-13.6.9" ];
      };

      packages = {
        rtc-helper = pkgs.callPackage ./shellscripts/rtc-helper.nix { };
        nas = pkgs.callPackage ./shellscripts/nas.nix { };
        backup-usb = pkgs.callPackage ./shellscripts/backup-usb.nix { };

        # s25rttr = pkgs.callPackage ./s25rttr {
        #   SDL2 = pkgs.SDL2.override { withStatic = true; };
        # };

        asus-touchpad-numpad-driver = pkgs.python3.pkgs.callPackage ./asus-touchpad-numpad-driver { };

        jameica-fhs = pkgs.callPackage ./jameica/fhsenv.nix { };

        deezer = pkgsDeezer.callPackage ./deezer { };

        linux_xanmod_x86_64_v3 = pkgs.callPackage ./linux-xanmod-x86-64-v3 { };

        mesa_x86_64_v3 = overrideMesa pkgs.mesa;
        i686-mesa_x86_64_v3 = overrideMesa pkgs.pkgsi686Linux.mesa;
      };
    in
    {
      packages."${system}" = packages;
      hydraJobs."${system}" = packages;
    }
  );
}
