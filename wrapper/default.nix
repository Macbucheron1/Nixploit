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

    # https://gist.github.com/CMCDragonkai/9b65cbb1989913555c203f4fa9c23374
    nativeBuiltInputs = with pkgs; [
      makeWrapper
    ];

    # TODO: use https://ryantm.github.io/nixpkgs/languages-frameworks/go/#var-go-ldflags
    # To replace a global var for nix / git / xpra. also useful to get the version
    postInstall = ''
      wrapProgram $out/bin/${pname} --prefix PATH : ${pkgs.lib.makeBinPath runtimePackages}
    '';
  };
  inherit devPackages;
}
