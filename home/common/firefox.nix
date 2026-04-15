{ pkgs, firefox-addons, ... }:
{
  programs.firefox = {
    enable = true;

    profiles.default = {
      isDefault = true;

      search = {
        force = true;
        default = "ddg";
        engines = {
          google.metaData.hidden = true;
        };
      };

      settings = {
        "browser.startup.page" = 1;
        "browser.startup.homepage" = "https://duckduckgo.com/";
        "extensions.autoDisableScopes" = 0;
      };

      bookmarks = {
        force = true;
        settings = [{
          toolbar = true;
          bookmarks = [
            {
              name = "Github";
              url = "https://github.com/";
            }
            {
              name = "ChatGPT";
              url = "https://chatgpt.com";
            }
            {
              name = "POC in Github";
              url = "https://poc-in-github.motikan2010.net/";
            }
            {
              name = "Bloodhound";
              url = "http://localhost:9090/ui/login";
            }
            {
              name = "Wiki";
              bookmarks = [
                {
                  name = "TheHackerRecipes";
                  url = "https://www.thehacker.recipes/";
                }
                {
                  name = "HackTricks";
                  url = "https://hacktricks.wiki/en/index.html";
                }
                {
                  name = "PayloadAllTheThings";
                  url = "https://github.com/swisskyrepo/PayloadsAllTheThings/";
                }
              ];
            }
            {
              name = "Plateform";
              bookmarks = [
                {
                  name = "HackTheBox";
                  url = "https://app.hackthebox.com/home";
                }
                {
                  name = "Root-Me";
                  url = "https://www.root-me.org/";
                }
                {
                  name = "PortSwigger";
                  url = "https://portswigger.net/web-security";
                }
              ];
            }
          ];
        }];
      };

      extensions.packages = with firefox-addons.packages.${pkgs.stdenv.hostPlatform.system}; [
        ublock-origin
        bitwarden
        darkreader
        privacy-badger
        vimium
      ];

      extraConfig = builtins.readFile ./better-fox.js;
    };
  };

  stylix.targets.firefox.profileNames = [ "default" ];
}
