{ pkgs, lib, concatHistory, ... }:
{
  home.packages = lib.mkAfter (with pkgs; [
    burpsuite
    feroxbuster
    wpscan
    whatweb
  ]);

  my.histories.web = concatHistory "web-history" [
    ./history/feroxbuster
    ./history/wpscan
    ./history/whatweb
  ];

  programs.burp = {
    enable = true;
    settings = {
      display.user_interface = {
        look_and_feel = "Dark";
      };
    };
    extensions = {
      "json-web-tokens".enable = true;
      "mcp-server".enable = true;
    };
  };
}
