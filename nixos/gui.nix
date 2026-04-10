{ ... }:
{
  environment.variables = {
    DISPLAY = ":0";
    XAUTHORITY = "/mnt/.config/.Xauthority";
    XDG_RUNTIME_DIR = "/run/user/1000";
    WAYLAND_DISPLAY = "wayland-0";
    MOZ_ENABLE_WAYLAND = "1";
    GDK_BACKEND = "wayland";
    _JAVA_AWT_WM_NONREPARENTING = "1";
  };

  systemd.services.gui-links = {
    description = "Prepare GUI socket links";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      install -d -m 0700 -o user -g users /run/user/1000
      mkdir -p /tmp/.X11-unix
      ln -sf /mnt/.config/wayland-0 /run/user/1000/wayland-0
      ln -sf /mnt/.config/.X11-unix/X0 /tmp/.X11-unix/X0
    '';
  };
}
