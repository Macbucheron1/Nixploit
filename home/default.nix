{ username, pkgs, lib, ... }:
let
  # Custom wordlists. Search them in nixpkgs to add more or wrap them yourself
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
    # Function to add histories to the shell history
    _module.args = {
      concatHistory = import ../lib/concatHistory.nix { inherit pkgs lib; };
    };

    home.username = username;
    home.homeDirectory = "/home/${username}";
    home.stateVersion = "26.05";

    programs.home-manager.enable = true;

    home.packages =
      (with pkgs; [
        firefox-bin
        myWordlists
        wireshark
      ]) ++ [
        fzf-wordlists
      ];
  };
}
