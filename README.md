# Nixploit 

## Usage

On the host, make sure the firewall allows DHCPv4 requests from the Incus bridge
`nixploit-net` to the host DHCP server, i.e. UDP destination port 67. 

For GUI support, the host runtime must also provide:

- a running Wayland compositor and/or X11/Xwayland server
- readable GUI sockets on the host side (`$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY` and/or `/tmp/.X11-unix/X*`)
- for X11 clients, an authorization mechanism that actually works on the host session:
  either a valid X11 cookie, or an `xhost` fallback such as `xhost +local:`

```bash
chmod +x maker.sh
./maker.sh up
```

## Image vs Runtime

The Nix image is now meant to stay host-agnostic:

- `flake.nix` is the source of truth for the container `rootPassword` and `hostname`
- the image must not assume a host user, host home, host UID 1000, `wayland-1`, `.Xauthority`, or any fixed GUI socket path
- GUI/GPU support is still part of the product, but host-specific socket mounting and device wiring belong to the runtime layer, not the image
- in other words: the image should work regardless of whether the host uses Wayland, X11, or both, as long as the runtime provides the expected mounts/devices

The wrapper therefore needs to:

- detect the current host user, UID/GID, GUI stack, and GPU availability
- detect Wayland, X11, or both, and provide the right Incus mounts/devices
- normalize those runtime resources into the container paths expected by the image
- shift mounted GUI resources so the unprivileged Incus container can actually open them
- distinguish between X11 transport and X11 authorization: mounting `/tmp/.X11-unix` is not enough on its own
- prefer a valid X11 cookie when available, but keep an `xhost` fallback for host sessions where Xwayland auth is not exposed in a portable way
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
- Wayland socket detection & passing
- X11 socket detection, shifted mounting, and `DISPLAY` wiring
- X11 authorization handling: valid cookie if available, `xhost +local:` fallback otherwise
- host prechecks for `DISPLAY`, `XDG_RUNTIME_DIR`, Wayland/X11 sockets, and X11 auth viability
- network mode selection 
- vpn start 
- shares nix store
