{
  self,
  config,
  inputs,
  lib,
  withSystem,
  ...
}:
let
  inherit (builtins) hashString pathExists;
  inherit (lib)
    mapAttrs
    attrValues
    substring
    genAttrs
    ;

  cfg = config.fp-lib.nixosConfigurations;

  # Generates a lib.nixosSystem based on given name and config.
  generateSystem = mapAttrs (
    name: conf:
    withSystem conf.hostPlatform.system (
      {
        system,
        inputs',
        self',
        ...
      }:
      let
        inherit (conf.nixpkgs) lib;
        configDir = "${self}/machines/${name}";
        extraArgs = {
          inherit
            self
            self'
            inputs
            inputs'
            ;
          flakeConfig = config;
        };
        hasSystemImpermanence = pathExists "${configDir}/impermanence.nix";
        hasHomeImpermanence = user: pathExists "${configDir}/impermanence-home-${user}.nix";
      in
      lib.nixosSystem {
        modules =
          [
            {
              inherit (conf) disabledModules;

              _module.args = extraArgs;
              nixpkgs = {
                inherit (conf) hostPlatform;
              };
              networking = {
                hostName = name;
                hostId = substring 0 8 (hashString "md5" "${name}");
              };
              system.configurationRevision = self.rev or "dirty";
              nix = {
                registry = {
                  nixpkgs.flake = conf.nixpkgs;
                  nixos-config.flake = inputs.self;
                };
                nixPath = [ "nixpkgs=/etc/nix/inputs/nixpkgs" ];
              };
              environment.etc."nix/inputs/nixpkgs".source = conf.nixpkgs.outPath;
            }

            inputs.sops-nix.nixosModules.sops
            { sops.defaultSopsFile = "${configDir}/secrets.yaml"; }
            "${configDir}/configuration.nix"
          ]
          ++ lib.optionals (pathExists "${configDir}/hardware.nix") [ "${configDir}/hardware.nix" ]
          ++ lib.optionals hasSystemImpermanence [
            inputs.impermanence.nixosModules.impermanence
            "${configDir}/impermanence.nix"
          ]
          ++ (attrValues config.flake.nixosModules)
          ++ conf.extraModules
          ++ lib.optionals (conf.home-manager.input != null) [
            conf.home-manager.input.nixosModule
            (
              { config, ... }:
              {
                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  extraSpecialArgs = extraArgs;
                  sharedModules =
                    [
                      inputs.sops-nix.homeManagerModule
                    ]
                    ++ (attrValues self.flakeModules.home-manager)
                    ++ conf.home-manager.extraModules;
                  users = genAttrs conf.home-manager.users (
                    name:
                    let
                      user = config.users.users.${name};
                    in
                    {
                      imports =
                        [
                          (
                            { config, ... }:
                            {
                              sops = {
                                age.keyFile = "${config.xdg.configHome}/sops/age/keys.txt";
                                defaultSopsFile = "${configDir}/secrets-home.yaml";
                                defaultSymlinkPath = "/run/user/${toString user.uid}/secrets";
                                defaultSecretsMountPoint = "/run/user/${toString user.uid}/secrets.d";
                              };
                            }
                          )
                        ]
                        ++ lib.optionals (pathExists "${configDir}/home.nix") [ "${configDir}/home.nix" ]
                        ++ lib.optionals (hasHomeImpermanence user) [
                          inputs.impermanence.homeManagerModules.impermanence
                          "${configDir}/impermanence-home-${user}.nix"
                        ];
                    }
                  );
                };
              }
            )
          ];
      }
    )
  );
in
{
  flake.nixosConfigurations = generateSystem cfg;
}
