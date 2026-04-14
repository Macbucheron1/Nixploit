{ pkgs }:
rec {
  wiremcp = pkgs.callPackage ./wiremcp.nix { };
}
