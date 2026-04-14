#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OPENGL_DRIVER_BUNDLE="${SCRIPT_DIR}/.cache/opengl-driver"

incus_cmd() {
  sudo incus "$@"
}

prepare_opengl_driver_bundle() {
  if [[ ! -d /run/opengl-driver ]]; then
    echo "GPU bundle error: /run/opengl-driver is missing on the host." >&2
    return 1
  fi

  if [[ -e "${OPENGL_DRIVER_BUNDLE}" && ! -w "${OPENGL_DRIVER_BUNDLE}" ]]; then
    sudo rm -rf "${OPENGL_DRIVER_BUNDLE}"
  else
    rm -rf "${OPENGL_DRIVER_BUNDLE}"
  fi
  mkdir -p "${OPENGL_DRIVER_BUNDLE}"

  # Incus can mount the host driver tree into the container, but the NixOS
  # opengl-driver output is full of absolute symlinks back into the host
  # /nix/store. Copying with -L materializes those symlinks into real files so
  # the container can dlopen NVIDIA/OpenCL libraries without mounting the host
  # store paths directly.
  cp -aL /run/opengl-driver/. "${OPENGL_DRIVER_BUNDLE}/"
}

check_firewall_dhcp() {
  local rules

  if command -v nft >/dev/null 2>&1 && rules="$(sudo nft list ruleset 2>/dev/null)"; then
    if printf '%s\n' "$rules" | grep -Eq 'iifname "nixploit-net".*udp dport 67.*accept|udp dport 67.*iifname "nixploit-net".*accept'; then
      echo "Firewall precheck OK: nft appears to allow DHCPv4 on nixploit-net."
      return 0
    fi

    echo "Firewall precheck warning: nft is active, but no allow rule for DHCPv4 on nixploit-net was found." >&2
    echo "The container launch will continue; DHCP will be verified after startup." >&2
    return 0
  fi

  if command -v iptables >/dev/null 2>&1 && rules="$(sudo iptables -S 2>/dev/null)"; then
    if printf '%s\n' "$rules" | grep -Eq '(-i nixploit-net|-A .*nixploit-net).*(-p udp).*--dport 67.*-j ACCEPT|(-p udp).*--dport 67.*(-i nixploit-net|-A .*nixploit-net).*-j ACCEPT'; then
      echo "Firewall precheck OK: iptables appears to allow DHCPv4 on nixploit-net."
      return 0
    fi

    echo "Firewall precheck warning: iptables is active, but no allow rule for DHCPv4 on nixploit-net was found." >&2
    echo "The container launch will continue; DHCP will be verified after startup." >&2
    return 0
  fi

  echo "Skipping firewall precheck: no readable nft/iptables ruleset." >&2
  echo "The container launch will continue; DHCP will be verified after startup." >&2
}

check_firewall_dns() {
  local rules nixos_fw_rules

  if command -v nft >/dev/null 2>&1 && rules="$(sudo nft list ruleset 2>/dev/null)"; then
    if printf '%s\n' "$rules" | grep -Fq 'table inet nixos-fw {'; then
      nixos_fw_rules="$(
        printf '%s\n' "$rules" | awk '
          /^table inet nixos-fw \{/ { in_table = 1 }
          in_table { print }
          in_table && /^\}/ { exit }
        '
      )"

      if printf '%s\n' "$nixos_fw_rules" | grep -Eq 'iifname "nixploit-net".*udp dport 53.*accept|udp dport 53.*iifname "nixploit-net".*accept'; then
        echo "Firewall precheck OK: nixos-fw appears to allow DNS/UDP on nixploit-net."
      else
        echo "Firewall precheck warning: nixos-fw is active, but no allow rule for DNS/UDP on nixploit-net was found." >&2
      fi

      if printf '%s\n' "$nixos_fw_rules" | grep -Eq 'iifname "nixploit-net".*tcp dport 53.*accept|tcp dport 53.*iifname "nixploit-net".*accept'; then
        echo "Firewall precheck OK: nixos-fw appears to allow DNS/TCP on nixploit-net."
        return 0
      fi

      echo "Firewall precheck warning: nixos-fw is active, but no allow rule for DNS/TCP on nixploit-net was found." >&2
      echo "The container launch will continue; Incus bridge DNS may still fail even if Incus installed its own nft rules." >&2
      return 0
    fi

    if printf '%s\n' "$rules" | grep -Eq 'iifname "nixploit-net".*udp dport 53.*accept|udp dport 53.*iifname "nixploit-net".*accept'; then
      echo "Firewall precheck OK: nft appears to allow DNS/UDP on nixploit-net."
    else
      echo "Firewall precheck warning: nft is active, but no allow rule for DNS/UDP on nixploit-net was found." >&2
    fi

    if printf '%s\n' "$rules" | grep -Eq 'iifname "nixploit-net".*tcp dport 53.*accept|tcp dport 53.*iifname "nixploit-net".*accept'; then
      echo "Firewall precheck OK: nft appears to allow DNS/TCP on nixploit-net."
      return 0
    fi

    echo "Firewall precheck warning: nft is active, but no allow rule for DNS/TCP on nixploit-net was found." >&2
    echo "The container launch will continue; DNS will likely fail if the bridge DNS is firewalled." >&2
    return 0
  fi

  if command -v iptables >/dev/null 2>&1 && rules="$(sudo iptables -S 2>/dev/null)"; then
    if printf '%s\n' "$rules" | grep -Eq '(-i nixploit-net|-A .*nixploit-net).*(-p udp).*--dport 53.*-j ACCEPT|(-p udp).*--dport 53.*(-i nixploit-net|-A .*nixploit-net).*-j ACCEPT'; then
      echo "Firewall precheck OK: iptables appears to allow DNS/UDP on nixploit-net."
    else
      echo "Firewall precheck warning: iptables is active, but no allow rule for DNS/UDP on nixploit-net was found." >&2
    fi

    if printf '%s\n' "$rules" | grep -Eq '(-i nixploit-net|-A .*nixploit-net).*(-p tcp).*--dport 53.*-j ACCEPT|(-p tcp).*--dport 53.*(-i nixploit-net|-A .*nixploit-net).*-j ACCEPT'; then
      echo "Firewall precheck OK: iptables appears to allow DNS/TCP on nixploit-net."
      return 0
    fi

    echo "Firewall precheck warning: iptables is active, but no allow rule for DNS/TCP on nixploit-net was found." >&2
    echo "The container launch will continue; DNS will likely fail if the bridge DNS is firewalled." >&2
    return 0
  fi

  echo "Skipping firewall DNS precheck: no readable nft/iptables ruleset." >&2
  echo "The container launch will continue; DNS may fail if the bridge DNS is firewalled." >&2
}

verify_container_dhcp() {
  local ipv4

  echo "Waiting for DHCP on pentest eth0..."
  for _ in {1..30}; do
    ipv4="$(incus_cmd exec pentest -- sh -c "ip -4 -o addr show dev eth0 scope global | awk '{print \$4; exit}'" 2>/dev/null || true)"
    if [[ -n "$ipv4" && "$ipv4" != 169.254.* ]]; then
      echo "DHCP OK: pentest got $ipv4 on eth0."
      return 0
    fi
    sleep 1
  done

  echo "DHCP failed: pentest did not get a usable IPv4 address on eth0." >&2
  incus_cmd exec pentest -- journalctl -u dhcpcd --no-pager -b -n 60 >&2 || true
  return 1
}

mapfile -t image_paths < <(nix build .#metadata .#squashfs --no-link --print-out-paths)
if [[ "${#image_paths[@]}" -ne 2 ]]; then
  echo "Expected metadata and squashfs build outputs, got ${#image_paths[@]}." >&2
  exit 1
fi

metadata_path="${image_paths[0]}"
squashfs_path="${image_paths[1]}"
metadata_tar="$(find "$metadata_path" -type f -name '*.tar.xz' | head -n1)"
squashfs_file="$(find "$squashfs_path" -type f -name '*.squashfs' | head -n1)"

if [[ -z "${metadata_tar}" || -z "${squashfs_file}" ]]; then
  echo "Failed to resolve metadata tarball or squashfs file from Nix outputs." >&2
  exit 1
fi

prepare_opengl_driver_bundle
incus_cmd storage show nixploit-storage >/dev/null 2>&1 || incus_cmd storage create nixploit-storage dir
incus_cmd network show nixploit-net >/dev/null 2>&1 || incus_cmd network create nixploit-net ipv4.address=auto ipv4.nat=true ipv6.address=none
incus_cmd network set nixploit-net ipv4.dhcp=true ipv4.nat=true ipv6.address=none
check_firewall_dhcp
check_firewall_dns
incus_cmd profile show pentest-storage >/dev/null 2>&1 || incus_cmd profile create pentest-storage
sudo sh -c "incus profile edit pentest-storage < \"${SCRIPT_DIR}/incus/storage.yaml\""
incus_cmd profile show pentest-net >/dev/null 2>&1 || incus_cmd profile create pentest-net
sudo sh -c "incus profile edit pentest-net < \"${SCRIPT_DIR}/incus/net.yaml\""
incus_cmd profile show pentest-gui >/dev/null 2>&1 || incus_cmd profile create pentest-gui
sudo sh -c "incus profile edit pentest-gui < \"${SCRIPT_DIR}/incus/profil.yaml\""
incus_cmd profile show pentest-gpu >/dev/null 2>&1 || incus_cmd profile create pentest-gpu
sed "s|__OPENGL_DRIVER_BUNDLE__|${OPENGL_DRIVER_BUNDLE}|g" "${SCRIPT_DIR}/incus/gpu.yaml" | sudo incus profile edit pentest-gpu
incus_cmd image delete nixploit || true
incus_cmd delete pentest -f || true
incus_cmd image import "$metadata_tar" "$squashfs_file" --alias nixploit
incus_cmd launch nixploit pentest -p pentest-storage -p pentest-net -p pentest-gui -p pentest-gpu
verify_container_dhcp
