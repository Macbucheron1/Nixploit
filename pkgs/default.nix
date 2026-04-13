{ pkgs }:
rec {
  exegol = pkgs.callPackage ./exegol.nix { };
  exegol-mcp = pkgs.callPackage ./exegol-mcp.nix { };
  wiremcp = pkgs.callPackage ./wiremcp.nix { };
}
