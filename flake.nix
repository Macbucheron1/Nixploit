{
  description = "Pentest Incus image based on NixOS with Home Manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    burpsuite-nix = {
        url = "github:Red-Flake/burpsuite-nix";
        inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, nur, burpsuite-nix, ... }:
    let
      system = "x86_64-linux";
      incus-image = import ./incus {
        inherit nixpkgs home-manager nur burpsuite-nix system;
      };
    in {
     packages.${system} = {
        default = incus-image;
      };
    };
}
