{ pkgs }:
let
  pname = "nixploit";
  version = "0.1.0";

  runtimePackages = with pkgs; [
    nix
    git
    xpra
  ];

  devPackages = with pkgs; [
    go
  ] ++ runtimePackages;

in
{
  wrapper = pkgs.buildGoModule {
    inherit pname version;

    src = ./.;

    vendorHash = "sha256-+PoDjFmc8aHvyp9WXXtz8IB/95pN5wI1vIsjPyQJwnM=";

    nativeBuildInputs = with pkgs; [
      makeWrapper
    ];

    postInstall = ''
      wrapProgram $out/bin/${pname} \
        --prefix PATH : ${pkgs.lib.makeBinPath runtimePackages}
    '';
  };

  inherit devPackages;
}
