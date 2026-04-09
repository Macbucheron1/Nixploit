{ pkgs, ... }:

{
  home.username = "root";
  home.homeDirectory = "/root";
  home.stateVersion = "25.05";

  programs.home-manager.enable = true;

  programs.bash = {
    enable = true;

    shellAliases = {
      ll = "ls -alh";
      z = "zellij";
    };

    bashrcExtra = ''
      export PS1='[pentest:\u@\h \W]\$ '
      echo "Home Manager is active"
    '';
  };

  programs.zellij.enable = true;
}
