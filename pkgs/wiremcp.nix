{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  makeWrapper,
  nodejs,
  wireshark-cli,
}:

buildNpmPackage rec {
  pname = "wiremcp";
  version = "unstable-2025-07-10";

  src = fetchFromGitHub {
    owner = "0xkoda";
    repo = "WireMCP";
    rev = "7f45f8b2b4adeb76be8c6227eefb38533fdd6b1e";
    hash = "sha256-Vcl2k7uwFDq7hW0bhS40VS13YLttD4YiXeGsPE3Zqo8=";
  };

  npmDepsHash = "sha256-gcFiw01PGIzndtKSnrdr6Ao5vvjjt+y3YncYoltV3qM=";

  dontNpmBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  # Upstream currently does not ship package-lock.json, so vendor it alongside
  # the derivation in the package directory, which matches common nixpkgs practice.
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  postInstall = ''
    makeWrapper ${lib.getExe nodejs} $out/bin/wiremcp \
      --add-flags $out/lib/node_modules/wiremcp/index.js \
      --prefix PATH : ${lib.makeBinPath [ wireshark-cli ]}
  '';

  meta = with lib; {
    description = "Model Context Protocol server for network sleuthing with tshark";
    homepage = "https://github.com/0xkoda/WireMCP";
    changelog = "https://github.com/0xkoda/WireMCP/commits/${src.rev}";
    license = licenses.mit;
    mainProgram = "wiremcp";
    platforms = platforms.unix;
  };
}
