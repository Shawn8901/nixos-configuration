{
  cfg.perlless.nixos =
    { lib, modulesPath, ... }:
    {
      imports = [ "${modulesPath}/profiles/perlless.nix" ];
      # We dont build fully perlless yet
      system.forbiddenDependenciesRegexes = lib.mkForce [ ];
    };
}
