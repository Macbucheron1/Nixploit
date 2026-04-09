{ pkgs, lib, ... }:
{
  home.packages = lib.mkAfter (with pkgs; [
    netexec
    certipy
    python313Packages.bloodyad
  ]);

  my.histories.activeDirectory = pkgs.concatText "ad-history" [
    ./history/certipy
    ./history/netexec
    ./history/bloodyAD
  ];
}
