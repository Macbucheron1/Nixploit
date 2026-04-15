#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="${SCRIPT_DIR}/.cache"
STATE_FILE="${CACHE_DIR}/last-build.env"
OPENGL_DRIVER_BUNDLE="${CACHE_DIR}/opengl-driver"

PROJECT_PREFIX="nixploit"
DEFAULT_INSTANCE_NAME="${PROJECT_PREFIX}-dev"
STORAGE_POOL_NAME="${PROJECT_PREFIX}-storage"
NETWORK_NAME="${PROJECT_PREFIX}-net"
STORAGE_PROFILE_NAME="${PROJECT_PREFIX}-storage"
NETWORK_PROFILE_NAME="${PROJECT_PREFIX}-net"
GUI_PROFILE_NAME="${PROJECT_PREFIX}-gui"
GPU_PROFILE_NAME="${PROJECT_PREFIX}-gpu"

COMMAND=""
INSTANCE_NAME="${DEFAULT_INSTANCE_NAME}"
IMAGE_ALIAS=""
YES=0

incus_cmd() {
  sudo incus "$@"
}

usage() {
  cat <<'EOF'
Usage:
  ./maker.sh <command> [options]

Commands:
  build
  import-image
  prepare-runtime
  launch
  recreate
  destroy
  test-net
  up

Options:
  --name <instance-name>        Instance name (default: nixploit-dev)
  --image-alias <image-alias>   Override image alias from the last build
  --yes                         Confirm destructive actions
EOF
}

parse_args() {
  COMMAND="${1:-}"
  shift || true

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name)
        [[ $# -ge 2 ]] || {
          echo "Missing value for --name" >&2
          exit 1
        }
        INSTANCE_NAME="$2"
        shift 2
        ;;
      --image-alias)
        [[ $# -ge 2 ]] || {
          echo "Missing value for --image-alias" >&2
          exit 1
        }
        IMAGE_ALIAS="$2"
        shift 2
        ;;
      --yes)
        YES=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown argument: $1" >&2
        usage >&2
        exit 1
        ;;
    esac
  done
}

require_yes() {
  [[ "${YES}" -eq 1 ]] || {
    echo "Refusing destructive action without --yes" >&2
    exit 1
  }
}

write_state() {
  local metadata_tar="$1"
  local squashfs_file="$2"
  local image_alias="$3"

  mkdir -p "${CACHE_DIR}"
  cat > "${STATE_FILE}" <<EOF
METADATA_TAR=${metadata_tar}
SQUASHFS_FILE=${squashfs_file}
IMAGE_ALIAS=${image_alias}
EOF
}

load_state() {
  [[ -f "${STATE_FILE}" ]] || {
    echo "Missing build state at ${STATE_FILE}. Run: ./maker.sh build" >&2
    exit 1
  }

  # shellcheck disable=SC1090
  source "${STATE_FILE}"

  if [[ -n "${IMAGE_ALIAS:-}" ]]; then
    IMAGE_ALIAS="${IMAGE_ALIAS}"
  fi

  [[ -n "${METADATA_TAR:-}" && -n "${SQUASHFS_FILE:-}" && -n "${IMAGE_ALIAS:-}" ]] || {
    echo "Build state in ${STATE_FILE} is incomplete. Run: ./maker.sh build" >&2
    exit 1
  }
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

  # Materialize symlinks so container-mounted driver files do not depend on
  # host store paths being visible inside the instance.
  cp -aL /run/opengl-driver/. "${OPENGL_DRIVER_BUNDLE}/"
}

check_firewall_dhcp() {
  local rules

  if command -v nft >/dev/null 2>&1 && rules="$(sudo nft list ruleset 2>/dev/null)"; then
    if printf '%s\n' "$rules" | grep -Eq "iifname \"${NETWORK_NAME}\".*udp dport 67.*accept|udp dport 67.*iifname \"${NETWORK_NAME}\".*accept"; then
      echo "Firewall precheck OK: nft appears to allow DHCPv4 on ${NETWORK_NAME}."
      return 0
    fi

    echo "Firewall precheck warning: nft is active, but no allow rule for DHCPv4 on ${NETWORK_NAME} was found." >&2
    echo "The container launch will continue; DHCP will be verified after startup." >&2
    return 0
  fi

  if command -v iptables >/dev/null 2>&1 && rules="$(sudo iptables -S 2>/dev/null)"; then
    if printf '%s\n' "$rules" | grep -Eq "(-i ${NETWORK_NAME}|-A .*${NETWORK_NAME}).*(-p udp).*--dport 67.*-j ACCEPT|(-p udp).*--dport 67.*(-i ${NETWORK_NAME}|-A .*${NETWORK_NAME}).*-j ACCEPT"; then
      echo "Firewall precheck OK: iptables appears to allow DHCPv4 on ${NETWORK_NAME}."
      return 0
    fi

    echo "Firewall precheck warning: iptables is active, but no allow rule for DHCPv4 on ${NETWORK_NAME} was found." >&2
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

      if printf '%s\n' "$nixos_fw_rules" | grep -Eq "iifname \"${NETWORK_NAME}\".*udp dport 53.*accept|udp dport 53.*iifname \"${NETWORK_NAME}\".*accept"; then
        echo "Firewall precheck OK: nixos-fw appears to allow DNS/UDP on ${NETWORK_NAME}."
      else
        echo "Firewall precheck warning: nixos-fw is active, but no allow rule for DNS/UDP on ${NETWORK_NAME} was found." >&2
      fi

      if printf '%s\n' "$nixos_fw_rules" | grep -Eq "iifname \"${NETWORK_NAME}\".*tcp dport 53.*accept|tcp dport 53.*iifname \"${NETWORK_NAME}\".*accept"; then
        echo "Firewall precheck OK: nixos-fw appears to allow DNS/TCP on ${NETWORK_NAME}."
        return 0
      fi

      echo "Firewall precheck warning: nixos-fw is active, but no allow rule for DNS/TCP on ${NETWORK_NAME} was found." >&2
      echo "The container launch will continue; Incus bridge DNS may still fail even if Incus installed its own nft rules." >&2
      return 0
    fi

    if printf '%s\n' "$rules" | grep -Eq "iifname \"${NETWORK_NAME}\".*udp dport 53.*accept|udp dport 53.*iifname \"${NETWORK_NAME}\".*accept"; then
      echo "Firewall precheck OK: nft appears to allow DNS/UDP on ${NETWORK_NAME}."
    else
      echo "Firewall precheck warning: nft is active, but no allow rule for DNS/UDP on ${NETWORK_NAME} was found." >&2
    fi

    if printf '%s\n' "$rules" | grep -Eq "iifname \"${NETWORK_NAME}\".*tcp dport 53.*accept|tcp dport 53.*iifname \"${NETWORK_NAME}\".*accept"; then
      echo "Firewall precheck OK: nft appears to allow DNS/TCP on ${NETWORK_NAME}."
      return 0
    fi

    echo "Firewall precheck warning: nft is active, but no allow rule for DNS/TCP on ${NETWORK_NAME} was found." >&2
    echo "The container launch will continue; DNS will likely fail if the bridge DNS is firewalled." >&2
    return 0
  fi

  if command -v iptables >/dev/null 2>&1 && rules="$(sudo iptables -S 2>/dev/null)"; then
    if printf '%s\n' "$rules" | grep -Eq "(-i ${NETWORK_NAME}|-A .*${NETWORK_NAME}).*(-p udp).*--dport 53.*-j ACCEPT|(-p udp).*--dport 53.*(-i ${NETWORK_NAME}|-A .*${NETWORK_NAME}).*-j ACCEPT"; then
      echo "Firewall precheck OK: iptables appears to allow DNS/UDP on ${NETWORK_NAME}."
    else
      echo "Firewall precheck warning: iptables is active, but no allow rule for DNS/UDP on ${NETWORK_NAME} was found." >&2
    fi

    if printf '%s\n' "$rules" | grep -Eq "(-i ${NETWORK_NAME}|-A .*${NETWORK_NAME}).*(-p tcp).*--dport 53.*-j ACCEPT|(-p tcp).*--dport 53.*(-i ${NETWORK_NAME}|-A .*${NETWORK_NAME}).*-j ACCEPT"; then
      echo "Firewall precheck OK: iptables appears to allow DNS/TCP on ${NETWORK_NAME}."
      return 0
    fi

    echo "Firewall precheck warning: iptables is active, but no allow rule for DNS/TCP on ${NETWORK_NAME} was found." >&2
    echo "The container launch will continue; DNS will likely fail if the bridge DNS is firewalled." >&2
    return 0
  fi

  echo "Skipping firewall DNS precheck: no readable nft/iptables ruleset." >&2
  echo "The container launch will continue; DNS may fail if the bridge DNS is firewalled." >&2
}

ensure_profile() {
  local name="$1"
  local file="$2"

  incus_cmd profile show "$name" >/dev/null 2>&1 || incus_cmd profile create "$name"
  sudo sh -c "incus profile edit \"$name\" < \"$file\""
}

ensure_gpu_profile() {
  incus_cmd profile show "${GPU_PROFILE_NAME}" >/dev/null 2>&1 || incus_cmd profile create "${GPU_PROFILE_NAME}"
  sed "s|__OPENGL_DRIVER_BUNDLE__|${OPENGL_DRIVER_BUNDLE}|g" \
    "${SCRIPT_DIR}/incus/gpu.yaml" | sudo incus profile edit "${GPU_PROFILE_NAME}"
}

verify_container_dhcp() {
  local instance_name="$1"
  local iface="${2:-eth0}"
  local ipv4

  echo "Waiting for DHCP on ${instance_name} ${iface}..."
  for _ in {1..30}; do
    ipv4="$(
      incus_cmd exec "$instance_name" -- sh -c \
        "ip -4 -o addr show dev ${iface} scope global | awk '{print \$4; exit}'" \
        2>/dev/null || true
    )"
    if [[ -n "$ipv4" && "$ipv4" != 169.254.* ]]; then
      echo "DHCP OK: ${instance_name} got ${ipv4} on ${iface}."
      return 0
    fi
    sleep 1
  done

  echo "DHCP failed: ${instance_name} did not get a usable IPv4 address on ${iface}." >&2
  incus_cmd exec "$instance_name" -- journalctl -u dhcpcd --no-pager -b -n 60 >&2 || true
  return 1
}

verify_container_dns() {
  local instance_name="$1"

  echo "Testing DNS resolution in ${instance_name}..."
  if incus_cmd exec "$instance_name" -- sh -lc 'nslookup google.com >/dev/null 2>&1'; then
    echo "DNS OK: ${instance_name} resolved google.com."
    return 0
  fi

  echo "DNS failed: ${instance_name} could not resolve google.com." >&2
  incus_cmd exec "$instance_name" -- sh -lc 'cat /etc/resolv.conf >&2; nslookup -debug google.com >&2 || true'
  return 1
}

cmd_build() {
  local metadata_path squashfs_path metadata_tar squashfs_file git_ref image_alias

  mkdir -p "${CACHE_DIR}"

  mapfile -t image_paths < <(nix build .#metadata .#squashfs --no-link --print-out-paths)
  [[ "${#image_paths[@]}" -eq 2 ]] || {
    echo "Expected metadata and squashfs build outputs, got ${#image_paths[@]}." >&2
    exit 1
  }

  metadata_path="${image_paths[0]}"
  squashfs_path="${image_paths[1]}"
  metadata_tar="$(find "$metadata_path" -type f -name '*.tar.xz' | head -n1)"
  squashfs_file="$(find "$squashfs_path" -type f -name '*.squashfs' | head -n1)"

  [[ -n "${metadata_tar}" && -n "${squashfs_file}" ]] || {
    echo "Failed to resolve metadata tarball or squashfs file from Nix outputs." >&2
    exit 1
  }

  git_ref="$(git rev-parse --short HEAD 2>/dev/null || date +%s)"
  image_alias="${IMAGE_ALIAS:-${PROJECT_PREFIX}-dev-${git_ref}}"

  write_state "${metadata_tar}" "${squashfs_file}" "${image_alias}"
  echo "Build complete."
  echo "State written to ${STATE_FILE}"
  echo "Image alias: ${image_alias}"
}

cmd_import_image() {
  load_state

  if incus_cmd image info "${IMAGE_ALIAS}" >/dev/null 2>&1; then
    echo "Image alias '${IMAGE_ALIAS}' already exists, skipping import."
    return 0
  fi

  incus_cmd image import "${METADATA_TAR}" "${SQUASHFS_FILE}" --alias "${IMAGE_ALIAS}"
}

cmd_prepare_runtime() {
  incus_cmd storage show "${STORAGE_POOL_NAME}" >/dev/null 2>&1 || incus_cmd storage create "${STORAGE_POOL_NAME}" dir
  incus_cmd network show "${NETWORK_NAME}" >/dev/null 2>&1 || incus_cmd network create "${NETWORK_NAME}" ipv4.address=auto ipv4.nat=true ipv6.address=none
  incus_cmd network set "${NETWORK_NAME}" ipv4.dhcp=true ipv4.nat=true ipv6.address=none

  check_firewall_dhcp
  check_firewall_dns

  ensure_profile "${STORAGE_PROFILE_NAME}" "${SCRIPT_DIR}/incus/storage.yaml"
  ensure_profile "${NETWORK_PROFILE_NAME}" "${SCRIPT_DIR}/incus/net.yaml"
  ensure_profile "${GUI_PROFILE_NAME}" "${SCRIPT_DIR}/incus/profil.yaml"

  prepare_opengl_driver_bundle
  ensure_gpu_profile
}

cmd_launch() {
  load_state

  incus_cmd image info "${IMAGE_ALIAS}" >/dev/null 2>&1 || {
    echo "Image '${IMAGE_ALIAS}' not found. Run: ./maker.sh import-image" >&2
    exit 1
  }

  if incus_cmd info "${INSTANCE_NAME}" >/dev/null 2>&1; then
    echo "Instance '${INSTANCE_NAME}' already exists. Use recreate or choose another name." >&2
    exit 1
  fi

  incus_cmd launch "${IMAGE_ALIAS}" "${INSTANCE_NAME}" \
    -p "${STORAGE_PROFILE_NAME}" \
    -p "${NETWORK_PROFILE_NAME}" \
    -p "${GUI_PROFILE_NAME}" \
    -p "${GPU_PROFILE_NAME}"
}

cmd_destroy() {
  require_yes

  if incus_cmd info "${INSTANCE_NAME}" >/dev/null 2>&1; then
    incus_cmd delete "${INSTANCE_NAME}" -f
  else
    echo "Instance '${INSTANCE_NAME}' does not exist."
  fi
}

cmd_recreate() {
  require_yes
  cmd_destroy
  cmd_launch
}

cmd_test_net() {
  verify_container_dhcp "${INSTANCE_NAME}" "eth0"
  verify_container_dns "${INSTANCE_NAME}"
}

cmd_up() {
  cmd_build
  cmd_import_image
  cmd_prepare_runtime
  cmd_launch
  cmd_test_net
}

main() {
  parse_args "$@"

  case "${COMMAND}" in
    build) cmd_build ;;
    import-image) cmd_import_image ;;
    prepare-runtime) cmd_prepare_runtime ;;
    launch) cmd_launch ;;
    recreate) cmd_recreate ;;
    destroy) cmd_destroy ;;
    test-net) cmd_test_net ;;
    up) cmd_up ;;
    ""|-h|--help)
      usage
      ;;
    *)
      echo "Unknown command: ${COMMAND}" >&2
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
