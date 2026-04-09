{
  description = "Pentest Incus image based on NixOS with Home Manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      incus-image = import ./incus-image.nix {
        inherit nixpkgs home-manager system;
      };
    in {
      packages.${system} = {
        incus-image = incus-image;
        default = incus-image;
      };
    };
}
