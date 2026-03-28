{
  den.aspects.root = {
    includes = [
      # <cfg/shell>
    ];

    nixos =
      { config, ... }:
      {
        sops.secrets.root = {
          sopsFile = ./secrets.yaml;
          neededForUsers = true;
        };

        users.users.root.hashedPasswordFile = config.sops.secrets.root.path;
      };
  };
}
