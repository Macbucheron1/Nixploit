{ nixpkgs, home-manager, system }:
let
  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };

  incusSystem = nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [
      ./configuration.nix
      "${nixpkgs}/nixos/modules/virtualisation/lxc-container.nix"
      home-manager.nixosModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.users.root = import ./home.nix;
        home-manager.users.user = import ./user.nix;
      }
    ];
  };

  metadataDrv = incusSystem.config.system.build.metadata;
  squashfsDrv = incusSystem.config.system.build.squashfs;
in
pkgs.runCommand "incus-image.tar.xz"
  {
    nativeBuildInputs = [
      pkgs.gnutar
      pkgs.xz
      pkgs.squashfsTools
      pkgs.findutils
      pkgs.coreutils
    ];
  } ''
  set -euo pipefail

  work="$(mktemp -d)"

  metadata_tar="$(find "${metadataDrv}" -type f -name '*.tar.xz' | head -n1)"
  squashfs_file="$(find "${squashfsDrv}" -type f -name '*.squashfs' | head -n1)"

  test -n "$metadata_tar"
  test -n "$squashfs_file"

  mkdir -p "$work/meta" "$work/image" "$work/rootfs"

  tar -xJf "$metadata_tar" -C "$work/meta"
  unsquashfs -quiet -dest "$work/rootfs" "$squashfs_file"

  test -f "$work/meta/metadata.yaml"

  cp "$work/meta/metadata.yaml" "$work/image/"

  if [ -d "$work/meta/templates" ]; then
    cp -a "$work/meta/templates" "$work/image/"
  fi

  mv "$work/rootfs" "$work/image/rootfs"

  tar -C "$work/image" -cJf "$out" .
''
