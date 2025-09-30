{ pkgs, lib, ... }:
let
  inherit (lib) mkDefault mkForce;
in
{
  documentation = {
    doc.enable = mkDefault false;
    dev.enable = mkDefault false;
    info.enable = mkDefault false;
    nixos.enable = mkDefault false;
    man.enable = mkDefault false;
  };

  system = {
    stateVersion = mkDefault "23.05";
    disableInstallerTools = true;
  };
  time.timeZone = "Europe/Berlin";

  i18n.defaultLocale = "de_DE.UTF-8";
  console = {
    earlySetup = true;
    font = "Lat2-Terminus16";
    keyMap = "de";
  };

  programs.command-not-found.enable = false;

  boot = {
    bcache.enable = false;
    enableContainers = false;
    tmp = {
      useTmpfs = mkDefault true;
      cleanOnBoot = true;
    };
    swraid.enable = mkDefault false;
  };

  environment = {
    systemPackages = [ pkgs.vim ];
    defaultPackages = mkForce [ ];
  };

  services = {
    lvm.enable = false;
    journald.extraConfig = ''
      SystemMaxUse=100M
      SystemMaxFileSize=50M
    '';
    dbus.implementation = "broker";
  };
  security.wrapperDirSize = "10M";
}
