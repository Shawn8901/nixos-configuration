{
  lib,
  pkgs,
  symlinkJoin,
  makeBinaryWrapper,
  testers,
  s25client-unwrapped,
}:

let
  gameDir = pkgs.requireFile {
    name = "S2";
    hashMode = "recursive";
    sha256 = "02vr1nk6lwhs76fk5dygi0l0lvk1x69z2qs3v9i7rix6m7rq7hpd";
    message = ''
      Unfortunately, we cannot download S2 Settlers Gold Edition automatically.
      Please purchase a legitimate copy of S2 Settlers Gold Edition and store the installation files to the nix-store like this:

      nix-store --add-fixed sha256 --recursive <Path to S2 Directory from Disc>
    '';
  };
in

symlinkJoin {
  pname = "s25client";
  inherit (s25client-unwrapped) version;

  nativeBuildInputs = [ makeBinaryWrapper ];

  paths = [ s25client-unwrapped ];

  postBuild = ''
    wrapProgram $out/bin/s25client --set RTTR_GAME_DIR ${gameDir}
    wrapProgram $out/bin/s25edit --set RTTR_GAME_DIR ${gameDir}
  '';

  passthru = {
    tests.version = testers.testVersion { package = s25client-unwrapped; };
  };

  meta = lib.recurseIntoAttrs (s25client-unwrapped.meta);
}
