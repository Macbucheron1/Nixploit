{ username ? "user", ... }:
{
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "25.05";

  programs.home-manager.enable = true;

  programs.bash = {
    enable = true;
  };

  programs.burp = {
    enable = true;
    settings = {
        display.user_interface = {
        look_and_feel = "Dark";
      };
    };
  };

  programs.zellij.enable = true;
}
