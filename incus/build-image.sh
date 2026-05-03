set -euo pipefail

work="$(mktemp -d)"

metadata_tar="$(find "$metadataDrv" -type f -name '*.tar.xz' | head -n1)"
squashfs_file="$(find "$squashfsDrv" -type f -name '*.squashfs' | head -n1)"

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
