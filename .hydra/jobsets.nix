{ nixpkgs, pulls, ... }:
let
  pkgs = import nixpkgs { };

  prs = builtins.fromJSON (builtins.readFile pulls);
  prJobsets = pkgs.lib.mapAttrs (num: info: {
    enabled = 1;
    hidden = false;
    description = "PR ${num}: ${info.title}";
    checkinterval = 60;
    schedulingshares = 20;
    enableemail = false;
    emailoverride = "";
    keepnr = 1;
    type = 1;
    flake = "github:shawn8901/nixos-configuration/pull/${num}/head";
  }) prs;
  mkFlakeJobset = branch: schedulingshares: {
    inherit schedulingshares;
    description = "Build ${branch}";
    checkinterval = "3600";
    enabled = "1";
    enableemail = false;
    emailoverride = "";
    keepnr = 3;
    hidden = false;
    type = 1;
    flake = "github:shawn8901/nixos-configuration/${branch}";
  };

  desc =
    prJobsets
    // {
      "main" = mkFlakeJobset "main" 100;
    }
    // {
      "staging-next" = mkFlakeJobset "staging-next-custom" 10;
    };

  log = {
    pulls = prs;
    jobsets = desc;
  };
in
{
  jobsets = pkgs.runCommand "spec-jobsets.json" { } ''
    cat >$out <<EOF
    ${builtins.toJSON desc}
    EOF
    # This is to get nice .jobsets build logs on Hydra
    cat >tmp <<EOF
    ${builtins.toJSON log}
    EOF
    ${pkgs.jq}/bin/jq . tmp
  '';
}
