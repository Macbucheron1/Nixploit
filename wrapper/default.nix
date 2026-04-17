{ pkgs }:
let
  pname = "nixploit";
  version = "1.0.0";
in
{
  wrapper = pkgs.buildGoModule {
    inherit pname version;
    src = ./.;
    proxyVendor = true;
    vendorHash = null;
  };

  devPackages = with pkgs; [
    go
  ];
}
