{ pkgs, wordlistsPkg ? pkgs.wordlists }:
pkgs.writeShellApplication {
  name = "fzf-wordlists";

  runtimeInputs = with pkgs; [
    fzf
    findutils
    file
    coreutils
    wordlistsPkg
  ];

  text = ''
    set -euo pipefail

    root="${wordlistsPkg}/share/wordlists"

    if [ ! -d "$root" ]; then
      echo "wordlists directory not found: $root" >&2
      exit 1
    fi

    find -L "$root" -type f 2>/dev/null | sort | fzf
  '';
}
