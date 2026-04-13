#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OPENGL_DRIVER_BUNDLE="${SCRIPT_DIR}/.cache/opengl-driver"

prepare_opengl_driver_bundle() {
  if [[ ! -d /run/opengl-driver ]]; then
    echo "GPU bundle error: /run/opengl-driver is missing on the host." >&2
    return 1
  fi

  rm -rf "${OPENGL_DRIVER_BUNDLE}"
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

verify_container_dhcp() {
  local ipv4

  echo "Waiting for DHCP on pentest eth0..."
  for _ in {1..30}; do
    ipv4="$(incus exec pentest -- sh -c "ip -4 -o addr show dev eth0 scope global | awk '{print \$4; exit}'" 2>/dev/null || true)"
    if [[ -n "$ipv4" && "$ipv4" != 169.254.* ]]; then
      echo "DHCP OK: pentest got $ipv4 on eth0."
      return 0
    fi
    sleep 1
  done

  echo "DHCP failed: pentest did not get a usable IPv4 address on eth0." >&2
  incus exec pentest -- journalctl -u dhcpcd --no-pager -b -n 60 >&2 || true
  return 1
}

nix build .
prepare_opengl_driver_bundle
incus storage show nixploit-storage >/dev/null 2>&1 || incus storage create nixploit-storage dir
incus network show nixploit-net >/dev/null 2>&1 || incus network create nixploit-net ipv4.address=auto ipv4.nat=true ipv6.address=none
incus network set nixploit-net ipv4.dhcp=true ipv4.nat=true ipv6.address=none
check_firewall_dhcp
incus profile show pentest-storage >/dev/null 2>&1 || incus profile create pentest-storage
incus profile edit pentest-storage < incus/pentest-storage.yaml
incus profile show pentest-net >/dev/null 2>&1 || incus profile create pentest-net
incus profile edit pentest-net < incus/pentest-net.yaml
incus profile show pentest-gui >/dev/null 2>&1 || incus profile create pentest-gui
sed "s|__OPENGL_DRIVER_BUNDLE__|${OPENGL_DRIVER_BUNDLE}|g" incus/pentest-profil.yaml | incus profile edit pentest-gui
incus image delete nixploit || true
incus delete pentest -f || true
incus image import ./result --alias nixploit
incus launch nixploit pentest -p pentest-storage -p pentest-net -p pentest-gui
verify_container_dhcp
