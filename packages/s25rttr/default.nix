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

  message = ''
    Copy the S2 folder of the Settler 2 Gold Edition to /var/lib/s25rttr/S2/".
  '';

  src = fetchFromGitHub {
    owner = "Return-To-The-Roots";
    repo = "s25client";
    rev = "14c951b36f336a6918a8b4f4675dc23546737d6c";
    fetchSubmodules = true;
    hash = "sha256-ZV2lZyFJf3twZkkKTFViFeSifwub05+21EKj2HNedjw=";
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

  env.NIX_CFLAGS_COMPILE = toString [ "-Wno-error=deprecated-declarations" ];

  cmakeBuildType = "Release";
  cmakeFlags = [
    "-DRTTR_VERSION=20260121"
    "-DRTTR_REVISION=${finalAttrs.src.rev}"
    "-DRTTR_USE_SYSTEM_LIBS=ON"
    "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"
    "-DRTTR_INSTALL_PLACEHOLDER=OFF"
    "-DRTTR_GAMEDIR=/var/lib/s25rttr/S2/"
  ];

  passthru.runUpdate = true;
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
  };
})
