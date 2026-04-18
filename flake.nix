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

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ nixpkgs, ... }:
    let
      system = "x86_64-linux";

      # --- CHANGEME ---
      nixploit = {
        container = {
          rootPassword = "root";
          hostname = "nixploit";
        };

        services = {
          bloodhound = {
            admin = {
              username = "admin";
              password = "Password1337";
            };

            database = {
              user = "bloodhound";
              name = "bloodhound";
              password = "bloodhound";
            };

            neo4j = {
              user = "neo4j";
              database = "neo4j";
              password = "Password1337";
              initialPassword = "Password1337";
            };
          };
        };
      };
      # ----------------

      incus-image = import ./incus {
        inherit inputs system nixploit;
      };

      pkgs = import nixpkgs { inherit system; };
      wrapper = import ./wrapper { inherit pkgs; };
    in {
     packages.${system} = {
        default = wrapper.wrapper;
        tarball = incus-image.tarball;
        metadata = incus-image.metadata;
        squashfs = incus-image.squashfs;
        wrapper = wrapper.wrapper;
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = wrapper.devPackages;
      };
    };
}
