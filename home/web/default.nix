{ pkgs, lib, concatHistory, ... }:
{
  home.packages = lib.mkAfter (with pkgs; [
    burpsuite
    feroxbuster
    wpscan
  ]);

  my.histories.web = concatHistory "web-history" [
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
