{ pkgs, ... }:
{
  stylix = {
    enable = true;
    polarity = "dark";

    # Gruvbox theme
    base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";

    # Catppuccin theme
    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.fira-code;
        name = "FiraCode Nerd Font";
      };

     sizes = {
        applications = 15;
        desktop = 15;
        popups = 15;
        terminal = 15;
      };
    };
  };
}
