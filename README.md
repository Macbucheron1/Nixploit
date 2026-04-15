# Nixploit 

## Usage

On the host, make sure the firewall allows DHCPv4 requests from the Incus bridge
`nixploit-net` to the host DHCP server, i.e. UDP destination port 67. 

```bash
chmod +x maker.sh
./maker.sh up
```

## Image vs Runtime

The Nix image is now meant to stay host-agnostic:

- `flake.nix` is the source of truth for the container `username`, `uid`, `gid`, and `hostname`
- the image must not assume a host user, host home, host UID 1000, `wayland-1`, `.Xauthority`, or any fixed GUI socket path
- GUI/GPU support is still part of the product, but host-specific socket mounting and device wiring belong to the runtime layer, not the image
- in other words: the image should work regardless of whether the host uses Wayland, X11, or both, as long as the runtime provides the expected mounts/devices

The future wrapper should therefore:

- detect the current host user, UID/GID, GUI stack, and GPU availability
- detect Wayland, X11, or both, and provide the right Incus mounts/devices
- normalize those runtime resources into the container paths expected by the image
- warn when only Wayland or only X11 is available
- support `--no-gui` and `--no-gpu` to bypass those checks intentionally

## Shortcut

```
# When tapping a command, will suggest autocompletion using fzf
alt tab
```

### a packager

- event monitor
- exegol-history

### Wrapper

- GPU detection & passing
- wayland & x11 socket detecion & passing
- network mode selection 
- vpn start 
