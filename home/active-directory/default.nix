{ pkgs, lib, concatHistory, ... }:
{
  home.packages = lib.mkAfter (with pkgs; [
    netexec
    certipy
    python313Packages.bloodyad
  ]);

  my.histories.activeDirectory = concatHistory "ad-history" [
    ./history/certipy
    ./history/netexec
    ./history/bloodyAD
  ];
}
