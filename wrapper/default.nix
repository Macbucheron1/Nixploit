{ pkgs }:
let
  pname = "nixploit";
  version = "1.0.0";
in
{
  wrapper = pkgs.buildGoModule {
    inherit pname version;
    src = ./.;
    vendorHash = null;
  };

  devPackages = with pkgs; [
    go
  ];
}
