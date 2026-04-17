{ pkgs }:
let
  pname = "nixploit";
  version = "1.0.0";
in
{
  wrapper = pkgs.buildGoModule {
    inherit pname version;
    src = ./.;
    vendorHash = "sha256-ZG6laZbSpGG14DgkfNFqWyfAJ4q2n0CA2Bbxl5rrWWA=";
  };

  devPackages = with pkgs; [
    go
  ];
}
