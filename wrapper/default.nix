{ pkgs }:
let
  pname = "nixploit";
  version = "1.0.0";
in
{
  wrapper = pkgs.buildGoModule {
    inherit pname version;
    src = ./.;
    vendorHash = "sha256-+PoDjFmc8aHvyp9WXXtz8IB/95pN5wI1vIsjPyQJwnM=";
  };

  devPackages = with pkgs; [
    go
  ];
}
