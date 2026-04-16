{ config, pkgs, lib, nixploit, redflake-packages, neo4j44pkgs, ... }:
let
  runtimeContract = import ./runtime-contract.nix;
in
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
    (import ./gui.nix { inherit runtimeContract; })
    ./theme.nix
    redflake-packages.nixosModules.bloodhound-ce
    ./bloodhound.nix
    (import ./nix-patch.nix { })
    (import ./users.nix { inherit nixploit; })
    (import ./network.nix { inherit lib nixploit; })
    (import ./gpu.nix { inherit pkgs lib runtimeContract; })
  ];

  system.stateVersion = "25.05";
}
