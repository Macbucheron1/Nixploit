{ pkgs, firefox-addons, ... }:
{
  programs.firefox = {
    enable = true;

    profiles.mac = {
      isDefault = true;
      settings = {
        "extensions.autoDisableScopes" = 0;
      };
      extensions.packages = with firefox-addons.packages.${pkgs.stdenv.hostPlatform.system}; [
        ublock-origin
        bitwarden
        darkreader
        privacy-badger
        vimium
      ];
    };
  };
}
