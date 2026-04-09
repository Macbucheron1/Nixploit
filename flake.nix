{
  description = "Pentest Incus image based on NixOS with Home Manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    burpsuite-nix = {
        url = "github:Red-Flake/burpsuite-nix";
        inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, burpsuite-nix, ... }:
    let
      system = "x86_64-linux";
      incus-image = import ./incus {
        inherit nixpkgs home-manager burpsuite-nix system;
      };
    in {
     packages.${system} = {
        default = incus-image;
      };
    };
}
