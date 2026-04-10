{ pkgs, lib, hostname, username, ... }:
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
  ];

  imports = [
    ./gui.nix
    ./theme.nix
    (import ./nix-patch.nix { inherit username; })
    (import ./users.nix { inherit username; })
    (import ./network.nix { inherit lib hostname; })
    (import ./cap-patch.nix { inherit pkgs lib; })
  ];

  system.stateVersion = "25.05";
}
