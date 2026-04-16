{ inputs, system, nixploit }:
let
  pkgs = import inputs.nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };

  mkHost = import ../lib/mkHost.nix inputs;

  incusSystem = mkHost {
    inherit system nixploit;
    modules = [
      "${inputs.nixpkgs}/nixos/modules/virtualisation/lxc-container.nix"
    ];
  };

  metadataDrv = incusSystem.config.system.build.metadata;
  squashfsDrv = incusSystem.config.system.build.squashfs;

  # Custom command to create a full image archive. Much slower then build meta dara & squashfs
  tarballDrv = pkgs.runCommand "incus-image.tar.xz"
    {
      nativeBuildInputs = [
        pkgs.bash
        pkgs.gnutar
        pkgs.xz
        pkgs.squashfsTools
        pkgs.findutils
        pkgs.coreutils
      ];
    } ''
    export metadataDrv="${metadataDrv}"
    export squashfsDrv="${squashfsDrv}"
    ${pkgs.bash}/bin/bash ${./build-image.sh}
    '';
in
{
  default = tarballDrv;
  tarball = tarballDrv;
  metadata = metadataDrv;
  squashfs = squashfsDrv;
}
