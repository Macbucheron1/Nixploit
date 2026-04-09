{ username ? "user", ... }:
{
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "25.05";

  programs.home-manager.enable = true;

  programs.bash = {
    enable = true;
    bashrcExtra = ''
      export PS1='[cacacacaca:\u@\h \W]\$ '
    '';
  };

  programs.zellij.enable = true;
}
