{ pkgs, lib, ... }:
{
  home.packages = lib.mkAfter (with pkgs; [
    nmap
    rustscan
  ]);

  my.histories.common = pkgs.concatText "common-history" [
    ./history/nmap
    ./history/rustscan
  ];
}
