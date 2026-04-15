{ config, pkgs, lib, nixploit, redflake-packages, neo4j44pkgs, ... }:
{
  boot.isContainer = true;

  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nix.settings.sandbox = false;

  environment.systemPackages = with pkgs; [
    bashInteractive
    coreutils
    busybox
  ];

  imports = [
    (import ./gui.nix { inherit nixploit; })
    ./theme.nix
    redflake-packages.nixosModules.bloodhound-ce
    ./bloodhound.nix
    (import ./nix-patch.nix { inherit nixploit; })
    (import ./users.nix { inherit nixploit; })
    (import ./network.nix { inherit lib nixploit; })
    (import ./cap-patch.nix { inherit pkgs lib; })
    (import ./gpu.nix { inherit pkgs lib; })
  ];

  system.stateVersion = "25.05";
}
