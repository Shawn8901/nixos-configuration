{ lib
, rustPlatform
, fetchFromGitHub
}:

rustPlatform.buildRustPackage rec {
  pname = "autoadb";
  version = "20200601";

  src = fetchFromGitHub {
    owner = "rom1v";
    repo = pname;
    rev = "7f8402983603a9854bf618a384f679a17cd85e2d";
    sha256 = "sha256-9Sv38dCtvbqvxSnRpq+HsIwF/rfLUVZbi0J+mltLres=";
  };

  cargoSha256 = "sha256-fmNySuOW+2HKIOIqIv/8W41ZXSmq3hbi+11yZBbhW5Q=";

  meta = with lib; {
    description = "Execute a command whenever a device is adb-connected";
    homepage = "https://github.com/rom1v/autoadb";
    license = licenses.asl20;
    maintainers = with maintainers; [ ];
  };
}
