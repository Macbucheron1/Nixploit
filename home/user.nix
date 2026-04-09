{ ... }:
{
  home.username = "user";
  home.homeDirectory = "/home/user";
  home.stateVersion = "25.05";

  programs.home-manager.enable = true;

  home.sessionVariables = {
    XDG_RUNTIME_DIR = "/run/user/1000";
    WAYLAND_DISPLAY = "wayland-0";
    MOZ_ENABLE_WAYLAND = "1";
    GDK_BACKEND = "wayland";
  };

  programs.bash = {
    enable = true;
    bashrcExtra = ''
      export PS1='[cacacacaca:\u@\h \W]\$ '
    '';

  };
}
