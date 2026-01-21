{
  stdenv,
  lib,
  fetchFromGitHub,
  git,
  cmake,
  pkg-config,
  boost,
  bzip2,
  curl,
  gettext,
  libiconv,
  libsamplerate,
  lua,
  miniupnpc,
  SDL2,
  SDL2_mixer,
  writeScript,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "s25rttr";
  version = "0.9.5-unstable-2026-01-21";

  src = fetchFromGitHub {
    owner = "Return-To-The-Roots";
    repo = "s25client";
    rev = "12da8bf447c6226ed4c126f5aaedbcf8fd34df5c";
    fetchSubmodules = true;
    hash = "sha256-7jQOV9Uuk7/Sv5YbXXZ9Y375fHfk32xIt24Va/d7r4Q=";
  };

  nativeBuildInputs = [
    cmake
    git
    pkg-config
  ];

  buildInputs = [
    boost
    bzip2
    curl
    gettext
    libiconv
    libsamplerate
    lua
    miniupnpc
    SDL2
    SDL2_mixer
  ];

  cmakeBuildType = "Release";
  cmakeFlags = [
    "-DRTTR_VERSION=20260121"
    "-DRTTR_REVISION=${finalAttrs.src.rev}"
    "-DRTTR_USE_SYSTEM_LIBS=ON"
    "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"
    "-DRTTR_INSTALL_PLACEHOLDER=OFF"
    "-DRTTR_GAMEDIR=./"
  ];

  passthru.runUpdate = false;
  passthru.updateScript = writeScript "update-s25rttr" ''
    #!/usr/bin/env nix-shell
    #!nix-shell -i bash -p curl jq common-updater-scripts

    version="$(curl -sL "https://api.github.com/repos/Return-To-The-Roots/s25client/releases" | jq 'map(select(.prerelease == false)) | .[0].tag_name | .[1:]' --raw-output)"
    update-source-version s25rttr "$version"
  '';

  meta = {
    description = "Return To The Roots (Settlers II(R) Clone)";
    homepage = "https://www.rttr.info/";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ shawn8901 ];
    mainProgram = "s25client";
  };
})
