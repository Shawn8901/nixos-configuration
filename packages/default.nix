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

        pytr = pkgs.pytr.overrideAttrs rec {
          version = "0.4.2.post1";

          patchPhase = ''
            substituteInPlace pyproject.toml --replace-fail 'version = "0.4.2"' 'version = "${version}"'
          '';

          src = pkgs.fetchFromGitHub {
            owner = "pytr-org";
            repo = "pytr";
            rev = "9b49e3f6d22dd6f752299d67f1ec21d72a65733c";
            hash = "sha256-ifXHzULuS+CyGsnNuCRnIEFIZACsmUYn+bN4HoKOfp4=";
          };

        };

        jameica-fhs = pkgs.callPackage ./jameica/fhsenv.nix { };
      };
    in
    {
      packages."${system}" = packages;
      hydraJobs."${system}" = packages;
    }
  );
}
