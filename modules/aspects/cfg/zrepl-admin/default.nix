{
  cfg.zrepl-admin.homeManager =
    { pkgs, lib, ... }:
    let
      generate-zrepl-ssl = pkgs.writeShellScriptBin "generate-zrepl-ssl" ''
        name=$1
        ${lib.getExe pkgs.openssl} req -x509 -sha256 -nodes -newkey rsa:4096 -days 365 -keyout $name.key -out $name.crt -addext "subjectAltName = DNS:$name" -subj "/CN=$name"
        ${lib.getExe pkgs.sops} set modules/aspects/hosts/$name/secrets.yaml '["zrepl"]' "\"$(awk '{printf "%s\\n", $0}' $name.key)\""
        rm $name.key

        mv $name.crt files/certs/zrepl/
      '';
    in
    {
      home.packages = [ generate-zrepl-ssl ];
    };
}
