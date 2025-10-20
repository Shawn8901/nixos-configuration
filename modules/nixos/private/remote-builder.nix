{
  config,
  lib,
  pkgs,
  ...
}:
let

  cfg = config.shawn8901.remote-builder;
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    types
    ;
in
{
  options = {
    shawn8901.remote-builder = {
      enable = mkEnableOption "Enables a the machine as remote builder";
      userName = mkOption {
        type = types.str;
        description = "User to be used for remote building";
        default = "builder";
      };
    };
  };

  config = mkIf cfg.enable {
    users.groups.builder = { };

    users.users.${cfg.userName} = {
      isSystemUser = true;
      shell = config.users.defaultUserShell;
      group = cfg.userName;
      openssh.authorizedKeys.keys =
        let
          # https://discourse.nixos.org/t/wrapper-to-restrict-builder-access-through-ssh-worth-upstreaming/25834
          wrapper-dispatch-ssh-nix = pkgs.writeShellScriptBin "wrapper-dispatch-ssh-nix" ''
            case $SSH_ORIGINAL_COMMAND in
              "nix-daemon --stdio")
                exec env NIX_SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt ${pkgs.nix}/bin/nix-daemon --stdio
                ;;
              "nix-store --serve --write")
                exec env NIX_SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt ${pkgs.nix}/bin/nix-store --serve --write
                ;;
              *)
                echo "Access only allowed for using the nix remote builder" 1>&2
                exit
            esac
          '';
        in
        [
          "restrict,pty,command=\"${lib.getExe wrapper-dispatch-ssh-nix}\" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGsHm9iUQIJVi/l1FTCIFwGxYhCOv23rkux6pMStL49N"
        ];
    };

    nix.settings = {
      builders-use-substitutes = lib.mkDefault true;
      trusted-users = [ cfg.userName ];
    };
  };
}
