{ nixpkgs, home-manager, burpsuite-nix, system }:
let
  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };

  mkHost = import ../lib/mkHost.nix {
    inherit nixpkgs home-manager burpsuite-nix;
  };

  incusSystem = mkHost {
    inherit system;
    hostname = "pentest";
    username = "user";
    modules = [
      "${nixpkgs}/nixos/modules/virtualisation/lxc-container.nix"
    ];
  };

  metadataDrv = incusSystem.config.system.build.metadata;
  squashfsDrv = incusSystem.config.system.build.squashfs;
in
pkgs.runCommand "incus-image.tar.xz"
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
  ''
