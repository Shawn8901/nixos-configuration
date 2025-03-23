{
  lib,
  buildFHSEnv,
  jameica,
  jre,
  stdenv,
  cairo,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  glibc,
  gtk2,
  libX11,
  nspr,
  nss,
  pango,
  libxcb,
  libXi,
  libXrender,
  libXext,
  dbus,
  alsa-lib,
  libXScrnSaver,
  libXcursor,
  libXtst,
  libxshmfence,
  libGLU,
  libGL,
  at-spi2-core,
  libgcrypt,
  cups,
  libdrm,
  wayland,
  libgbm,
  libxkbcommon,
  libXdamage,
  libXcomposite,
  libXfixes,
  libXrandr,
  libva,
  expat,
  udev,
  killall,
  webkitgtk_4_0,
  extraPkgs ? pkgs: [ ],
  extraLibraries ? pkgs: [ ],
}:
let
  fhsEnv = buildFHSEnv {
    name = "jameica";
    runScript = "jameica";
    targetPkgs =
      pkgs:
      [
        jre
        jameica
        stdenv.cc.cc.lib
        cairo
        fontconfig
        freetype
        gdk-pixbuf
        glib
        gtk2
        libX11
        nspr
        nss
        pango
        libXrender
        libxcb
        libXext
        libXi
        dbus

        alsa-lib
        libXScrnSaver
        libXcursor
        libXtst
        libxshmfence
        libGLU
        libGL
        at-spi2-core
        libgcrypt
        cups
        libdrm
        wayland
        libgbm
        libxkbcommon
        libXdamage
        libXcomposite
        libXrandr
        libXfixes
        expat
        libva
        udev

        webkitgtk_4_0

        killall
      ]
      ++ extraPkgs pkgs;

    inherit (jameica) meta;
  };
in
fhsEnv
