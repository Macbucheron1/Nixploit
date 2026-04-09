{ pkgs, lib, ... }:
{
  home.packages = lib.mkAfter (with pkgs; [
    burpsuite
  ]);

  programs.burp = {
    enable = true;
    settings = {
        display.user_interface = {
        look_and_feel = "Dark";
      };
    };
  };
}
