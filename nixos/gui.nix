{ runtimeContract, ... }:
let
  inherit (runtimeContract.runtime) gui;
  runtimeUser = "root";
  runtimeGroup = "root";
  runtimeDir = "/run/user/0";
  runtimeXAuthority = "${runtimeDir}/.Xauthority";
in
{
  environment.variables = {
    XDG_RUNTIME_DIR = runtimeDir;
    _JAVA_AWT_WM_NONREPARENTING = "1";
  };

  # When shell is launched this export all the GUI related env variables
  environment.loginShellInit = ''
    export XDG_RUNTIME_DIR=${runtimeDir}
    unset WAYLAND_DISPLAY GDK_BACKEND MOZ_ENABLE_WAYLAND DISPLAY

    if [ -e ${runtimeDir}/wayland-0 ]; then
      export WAYLAND_DISPLAY=wayland-0
      export MOZ_ENABLE_WAYLAND=1
      export GDK_BACKEND=wayland
    fi

    x_socket=""
    for candidate in /tmp/.X11-unix/X*; do
      [ -e "$candidate" ] || continue
      if [ -S "$candidate" ]; then
        x_socket="$candidate"
        break
      fi
      target="$(readlink -f "$candidate" 2>/dev/null || true)"
      if [ -n "$target" ] && [ -S "$target" ]; then
        x_socket="$candidate"
        break
      fi
    done
    if [ -n "$x_socket" ]; then
      export DISPLAY=":''${x_socket##*/X}"
    fi

    if [ -f ${runtimeXAuthority} ]; then
      export XAUTHORITY=${runtimeXAuthority}
    elif [ -f ${gui.xauthorityFile} ]; then
      export XAUTHORITY=${gui.xauthorityFile}
    fi

    if [ -n "$PS1" ] && [ "$PS1" = '\s-\v\$ ' ]; then
      export PS1='[\u@\h:\w]# '
    fi
  '';

  systemd.services.gui-runtime-dir = {
    description = "Prepare the per-user GUI runtime directory";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      install -d -m 0700 -o ${runtimeUser} -g ${runtimeGroup} ${runtimeDir}
    '';
  };

  systemd.services.gui-links = {
    description = "Link mounted GUI sockets into standard in-container paths";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" "gui-runtime-dir.service" ];
    requires = [ "gui-runtime-dir.service" ];
    serviceConfig.Type = "oneshot";
    script = ''
      install -d -m 0700 -o ${runtimeUser} -g ${runtimeGroup} ${runtimeDir}
      mkdir -p /tmp/.X11-unix

      if [ -e ${gui.waylandSocket} ]; then
        ln -sf ${gui.waylandSocket} ${runtimeDir}/wayland-0
      fi

      for x_socket in ${gui.x11SocketDir}/X*; do
        [ -e "$x_socket" ] || continue
        ln -sf "$x_socket" "/tmp/.X11-unix/''${x_socket##*/}"
      done

      if [ -f ${gui.xauthorityFile} ]; then
        install -m 0600 -o root -g root ${gui.xauthorityFile} ${runtimeXAuthority}
      fi

      chown -h ${runtimeUser}:${runtimeGroup} ${runtimeDir}/wayland-0 ${runtimeDir} 2>/dev/null || true
    '';
  };
}
