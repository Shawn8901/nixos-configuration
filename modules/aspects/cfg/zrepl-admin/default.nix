{
  cfg.zrepl-admin.homeManager =
    { pkgs, ... }:
    let
      generate-zrepl-ssl = pkgs.writeShellScriptBin "generate-zrepl-ssl" ''
        name=$1
        ${pkgs.openssl}/bin/openssl req -x509 -sha256 -nodes -newkey rsa:4096 -days 365 -keyout $name.key -out $name.crt -addext "subjectAltName = DNS:$name" -subj "/CN=$name"
      '';
    in
    {
      home.packages = [ generate-zrepl-ssl ];
    };
}
