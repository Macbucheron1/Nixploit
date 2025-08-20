{
  description = "Docker image with basic hacking tools";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: 
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      basePkgs    = import ./packages/base.nix { inherit pkgs; };

      networkPkgs = import ./packages/network.nix { inherit pkgs; };

      adPkgs      = import ./packages/ad.nix { inherit pkgs; };
    in {
      packages.${system}.dockerImage = pkgs.dockerTools.buildLayeredImage {
        name = "hacking-tools";
        tag = "latest";
        contents = basePkgs ++ networkPkgs ++ adPkgs;
        config.Cmd = [ "bash" ];
      };
    };
}
