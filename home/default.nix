{ username ? "user", pkgs, lib, config, ... }:
let
  myWordlists = pkgs.wordlists.override {
    lists = with pkgs; [
      rockyou
      seclists
    ];
  };

  # Script to quickly search through wordlists
  fzf-wordlists = import ./scripts/fzf-wordlists.nix {
    inherit pkgs;
    wordlistsPkg = myWordlists;
  };
in
{
  imports = [
    ./active-directory
    ./web
    ./common

    ./shell.nix
  ];

  options.my.histories = lib.mkOption {
    type = lib.types.attrsOf lib.types.path;
    default = { };
  };

  config = {
    home.username = username;
    home.homeDirectory = "/home/${username}";
    home.stateVersion = "25.05";

    programs.home-manager.enable = true;

    home.packages =
      (with pkgs; [
        firefox-bin
        myWordlists
      ]) ++ [
        fzf-wordlists
      ];
  };
}
