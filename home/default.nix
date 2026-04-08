{ pkgs, ... }: {
  home.username = "root";
  home.homeDirectory = "/root";

  programs.home-manager.enable = true;

  home.packages = (with pkgs; [
  ]);

  home.stateVersion = "25.05";
}
