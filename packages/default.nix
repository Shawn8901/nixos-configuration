{
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

        jameica-fhs = pkgs.callPackage ./jameica/fhsenv.nix { };
      };
    in
    {
      packages."${system}" = packages;
      hydraJobs."${system}" = packages;
    }
  );
}
