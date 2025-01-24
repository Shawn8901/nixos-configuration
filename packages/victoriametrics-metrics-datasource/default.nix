{
  lib,
  stdenv,
  fetchzip,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "victoriametrics-metrics-datasource";
  version = "0.12.2";

  src = fetchzip {
    url = "https://github.com/VictoriaMetrics/victoriametrics-datasource/releases/download/v${finalAttrs.version}/victoriametrics-metrics-datasource-v${finalAttrs.version}.zip";
    hash = "sha256-nlCGDWWfR50Ts+RYhbEi4a3iXfqT+dqR8c/b04r/EFU=";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    cp -r $src $out
    runHook postInstall
  '';

  passthru.runUpdate = true;

  meta = with lib; {
    homepage = "https://github.com/VictoriaMetrics/grafana-datasource";
    description = "Grafana Plugin for VictoriaMetrics";
    license = licenses.agpl3Only;
    maintainers = with maintainers; [ shawn8901 ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
})
