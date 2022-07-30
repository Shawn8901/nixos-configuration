{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "NoiseTorch";
  version = "0.12.2";

  src = fetchFromGitHub {
    owner = "noisetorch";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-gOPSMPH99Upi/30OnAdwSb7SaMV0i/uHB051cclfz6A=";
  };

  vendorSha256 = null;

  doCheck = false;

  ldflags = [ "-s" "-w" "-X main.version=${version}" "-X main.distribution=nix" ];

  subPackages = [ "." ];

  preBuild = ''
    make -C c/ladspa/
    go generate
    rm  ./scripts/*
  '';

  postInstall = ''
    install -D ./assets/icon/noisetorch.png $out/share/icons/hicolor/256x256/apps/noisetorch.png
    install -Dm444 ./assets/noisetorch.desktop $out/share/applications/noisetorch.desktop
  '';

  meta = with lib; {
    insecure = true;
    knownVulnerabilities =
      lib.optional (lib.versionOlder version "0.12") "https://github.com/noisetorch/NoiseTorch/releases/tag/v0.12.0";
    description = "Virtual microphone device with noise supression for PulseAudio";
    homepage = "https://github.com/noisetorch/NoiseTorch";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
    maintainers = with maintainers; [ panaeon lom ];
  };
}
