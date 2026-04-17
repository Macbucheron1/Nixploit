{ pkgs }:
let
  pname = "nixploit";
  version = "1.0.0";
in
{
  wrapper = pkgs.buildGoModule {
    inherit pname version;
    src = ./.;
    vendorHash = "sha256-P3qXV0FslSP6xDybxjVSzYrohfup+a7Cuj5K+z4dEhs=";
  };

  devPackages = with pkgs; [
    go
  ];
}
