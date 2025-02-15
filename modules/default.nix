{
  config.fp-lib.modules.nixos = {
    public = ./nixos/public;
    private = ./nixos/private;
  };

  config.fp-lib.modules.home-manager = {
    private = ./home-manager/private;
  };
}
