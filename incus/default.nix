{ nixpkgs, home-manager, nur, stylix, burpsuite-nix, mac-nixos, redflake-packages, neo4j44pkgs, firefox-addons, system, username, uid, gid, hostname }:
let
  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };

  mkHost = import ../lib/mkHost.nix {
    inherit nixpkgs home-manager nur stylix burpsuite-nix mac-nixos redflake-packages neo4j44pkgs firefox-addons;
  };

  incusSystem = mkHost {
    inherit system username uid gid hostname;
    modules = [
      "${nixpkgs}/nixos/modules/virtualisation/lxc-container.nix"
    ];
  };

  metadataDrv = incusSystem.config.system.build.metadata;
  squashfsDrv = incusSystem.config.system.build.squashfs;

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
