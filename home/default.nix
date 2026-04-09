{ username ? "user", pkgs, ... }:
{
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "25.05";

  # Default packages
  home.packages = (with pkgs; [
    firefox-bin
  ]);

  # add package and configuration for specialty
  imports = [
    ./active-directory.nix
    ./web.nix
  ];

  programs.home-manager.enable = true;

  programs.bash = {
    enable = true;
  };

  programs.zellij.enable = true;
}
