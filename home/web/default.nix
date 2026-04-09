{ pkgs, lib, ... }:
{
  home.packages = lib.mkAfter (with pkgs; [
    burpsuite
    feroxbuster
    wpscan
  ]);

  my.histories.web = pkgs.concatText "web-history" [
    ./history/feroxbuster
    ./history/wpscan
  ];

  programs.burp = {
    enable = true;
    settings = {
      display.user_interface = {
        look_and_feel = "Dark";
      };
    };
  };
}
