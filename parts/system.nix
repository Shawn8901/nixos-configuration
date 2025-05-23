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
        hasHomeImpermanence = userName: pathExists "${configDir}/impermanence-home-${userName}.nix";
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
                  nixos-config.flake = self;
                };
                nixPath = [ "nixpkgs=flake:nixpkgs" ];
              };
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
            conf.home-manager.input.nixosModules.home-manager
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
                    userName:
                    let
                      user = config.users.users.${userName};
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
                        ++ lib.optionals (hasHomeImpermanence name) [
                          inputs.impermanence.homeManagerModules.impermanence
                          "${configDir}/impermanence-home-${userName}.nix"
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
