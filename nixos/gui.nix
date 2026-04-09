{ ... }:
{
  environment.variables = {
    DISPLAY = ":0";
    XAUTHORITY = "/mnt/.config/.Xauthority";
    WAYLAND_DISPLAY = "/mnt/.config/wayland-0";
    MOZ_ENABLE_WAYLAND = "1";
    GDK_BACKEND = "wayland";
    _JAVA_AWT_WM_NONREPARENTING = "1";
  };

  systemd.services.x11-link = {
    description = "Prepare X11 socket link";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      mkdir -p /tmp/.X11-unix
      ln -sf /mnt/.config/.X11-unix/X0 /tmp/.X11-unix/X0
    '';
  };
}
