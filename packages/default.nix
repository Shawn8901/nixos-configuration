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

        s25rttr = pkgs.callPackage ./s25rttr { };

        #jameica-fhs = pkgs.callPackage ./jameica/fhsenv.nix { };
      };
    in
    {
      packages."${system}" = packages;
      hydraJobs."${system}" = packages;
    }
  );
}
