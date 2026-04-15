{ ... }:
let
  runtimeDir = "/run/user/0";
in
{
  environment.variables = {
    XDG_RUNTIME_DIR = runtimeDir;
    _JAVA_AWT_WM_NONREPARENTING = "1";
  };

  environment.loginShellInit = ''
    export XDG_RUNTIME_DIR=${runtimeDir}
    unset WAYLAND_DISPLAY GDK_BACKEND MOZ_ENABLE_WAYLAND DISPLAY

    if [ -e ${runtimeDir}/wayland-0 ]; then
      export WAYLAND_DISPLAY=wayland-0
      export MOZ_ENABLE_WAYLAND=1
      export GDK_BACKEND=wayland
    fi

    x_socket="$(find /tmp/.X11-unix -maxdepth 1 -type s -name 'X*' | sort | head -n1)"
    if [ -n "$x_socket" ]; then
      export DISPLAY=":''${x_socket##*/X}"
    fi

    if [ -f /mnt/.config/.Xauthority ]; then
      export XAUTHORITY=/mnt/.config/.Xauthority
    fi
  '';

  systemd.services.gui-runtime-dir = {
    description = "Prepare the per-user GUI runtime directory";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      install -d -m 0700 -o root -g root ${runtimeDir}
    '';
  };

  systemd.services.gui-links = {
    description = "Link mounted GUI sockets into standard in-container paths";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" "gui-runtime-dir.service" ];
    requires = [ "gui-runtime-dir.service" ];
    serviceConfig.Type = "oneshot";
    script = ''
      install -d -m 0700 -o root -g root ${runtimeDir}
      mkdir -p /tmp/.X11-unix

      if [ -e /mnt/.config/wayland-0 ]; then
        ln -sf /mnt/.config/wayland-0 ${runtimeDir}/wayland-0
      fi

      for x_socket in /mnt/.config/.X11-unix/X*; do
        [ -e "$x_socket" ] || continue
        ln -sf "$x_socket" "/tmp/.X11-unix/''${x_socket##*/}"
      done

      if [ -f /mnt/.config/.Xauthority ]; then
        chmod 0600 /mnt/.config/.Xauthority || true
      fi
    '';
  };
}
