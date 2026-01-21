{
  withSystem,
  ...
}:
{
  flake = withSystem "x86_64-linux" (
    { system, pkgs, ... }:
    let
      packages = {

        generate-zrepl-ssl = pkgs.callPackage ./shellscripts/generate-zrepl-ssl.nix { };

        rtc-helper = pkgs.callPackage ./shellscripts/rtc-helper.nix { };
        backup-usb = pkgs.callPackage ./shellscripts/backup-usb.nix { };

        s25client-unwrapped = pkgs.callPackage ./s25client-unwrapped { };
        s25client = pkgs.callPackage ./s25client { inherit (packages) s25client-unwrapped; };

        #jameica-fhs = pkgs.callPackage ./jameica/fhsenv.nix { };
      };
    in
    {
      packages."${system}" = packages;
      hydraJobs."${system}" = packages;
    }
  );
}
