{ pkgs, lib, hostname, username, ... }:
{
  boot.isContainer = true;

  networking.hostName = lib.mkDefault hostname;

  networking.nameservers = [ "1.1.1.1" "1.0.0.1" ];

  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nix.settings.sandbox = false;

  environment.systemPackages = with pkgs; [
    bashInteractive
    coreutils
  ];

  imports = [
    ./gui.nix
    ./theme.nix
    (import ./nix-patch.nix { inherit username; })
    (import ./users.nix { inherit username; })
  ];

  system.stateVersion = "25.05";
}
