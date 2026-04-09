{ pkgs, lib, ... }:

{
  boot.isContainer = true;

  networking.hostName = "pentest";

  networking.useHostResolvConf = lib.mkForce false;
  services.resolved.enable = false;
  networking.nameservers = [ "1.1.1.1" "1.0.0.1" ];

  users.mutableUsers = false;
  users.users.root.initialPassword = "root";

  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nix.settings.sandbox = false;

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" ];

  environment.variables.PATH =
    "/root/.nix-profile/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/system/sw/bin";

  environment.systemPackages = with pkgs; [
    bashInteractive
    coreutils
    netexec
    firefox-bin
    zellij
  ];

  system.stateVersion = "25.05";
}
