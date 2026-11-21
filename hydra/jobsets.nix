{
  nixpkgs,
  refs,
  pulls,
  system ? builtins.currentSystem,
  ...
}:
let
  pkgs = import nixpkgs { inherit system; };
  inherit (pkgs) lib;

  branches = builtins.fromJSON (builtins.readFile refs);
  pullRequests = builtins.fromJSON (builtins.readFile pulls);

  mkBuildJob = name: {
    schedulingshares = 100;
    description = "Build config branch ${name}";
    checkinterval = "600";
    enabled = "1";
    enableemail = false;
    emailoverride = "";
    keepnr = 1;
    hidden = false;
    type = 0;
    nixexprinput = "src";
    nixexprpath = "hydra/release.nix";
    inputs.src = {
      emailresponsible = false;
      type = "git";
      value = "http://github.com/shawn8901/nixos-configuration ${name}";
    };
  };

  mkPrJob = name: info: {
    schedulingshares = 100;
    description = "Build Update for ${info.head.ref}";
    checkinterval = "600";
    enabled = "1";
    enableemail = false;
    emailoverride = "";
    keepnr = 1;
    hidden = false;
    type = 0;
    nixexprinput = "src";
    nixexprpath = "hydra/release.nix";
    inputs = {
      src = {
        emailresponsible = false;
        type = "git";
        value = "http://github.com/shawn8901/nixos-configuration ${info.head.sha}";
      };
      pinUpdate = {
        emailresponsible = false;
        type = "boolean";
        value = if lib.hasPrefix "lon/" info.head.ref then "true" else "false";
      };
    };
  };

  branchJobs = lib.mapAttrs (branch: info: mkBuildJob branch) (
    lib.filterAttrs (branch: v: (!lib.hasPrefix "lon/" branch)) branches
  );
  prJobs = lib.mapAttrs' (
    prNumber: info: lib.nameValuePair ("PR: ${prNumber}") (mkPrJob prNumber info)
  ) pullRequests;
  desc = branchJobs // prJobs;
  log = {
    inputs = {
      prs = pullRequests;
      branches = branches;
    };
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
