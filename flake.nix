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

    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    burpsuite-nix = {
        url = "github:Red-Flake/burpsuite-nix";
        inputs.nixpkgs.follows = "nixpkgs";
    };

    mac-nixos = {
      url = "github:Macbucheron1/mac-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    redflake-packages = {
      url = "github:Red-Flake/packages";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    neo4j44pkgs.url = "github:NixOS/nixpkgs/7a339d87931bba829f68e94621536cad9132971a";
  };

  outputs = { nixpkgs, home-manager, nur, stylix, burpsuite-nix, mac-nixos, redflake-packages, neo4j44pkgs, ... }:
    let
      system = "x86_64-linux";

      # --- CHANGEME ---
      username = "user";
      hostname = "hostname";
      # ----------------

      incus-image = import ./incus {
        inherit nixpkgs home-manager nur stylix burpsuite-nix mac-nixos redflake-packages neo4j44pkgs system username hostname;
      };
    in {
     packages.${system} = {
        default = incus-image.default;
        tarball = incus-image.tarball;
        metadata = incus-image.metadata;
        squashfs = incus-image.squashfs;
      };
    };
}
