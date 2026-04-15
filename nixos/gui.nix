{ nixploit }:
let
  inherit (nixploit.container) username uid;
in
{
  environment.variables = {
    XDG_RUNTIME_DIR = "/run/user/${toString uid}";
    _JAVA_AWT_WM_NONREPARENTING = "1";
  };

  environment.loginShellInit = ''
    export XDG_RUNTIME_DIR=/run/user/${toString uid}

    if [ -e /run/user/${toString uid}/wayland-0 ]; then
      export WAYLAND_DISPLAY=wayland-0
      export MOZ_ENABLE_WAYLAND=1
      export GDK_BACKEND=wayland
    fi

    if [ -e /tmp/.X11-unix/X0 ]; then
      export DISPLAY=:0
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
      install -d -m 0700 -o ${username} -g ${username} /run/user/${toString uid}
    '';
  };

  systemd.services.gui-links = {
    description = "Link mounted GUI sockets into standard in-container paths";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" "gui-runtime-dir.service" ];
    requires = [ "gui-runtime-dir.service" ];
    serviceConfig.Type = "oneshot";
    script = ''
      install -d -m 0700 -o ${username} -g ${username} /run/user/${toString uid}
      mkdir -p /tmp/.X11-unix

      if [ -e /mnt/.config/wayland-0 ]; then
        ln -sf /mnt/.config/wayland-0 /run/user/${toString uid}/wayland-0
      fi

      if [ -e /mnt/.config/.X11-unix/X0 ]; then
        ln -sf /mnt/.config/.X11-unix/X0 /tmp/.X11-unix/X0
      fi
    '';
  };
}
