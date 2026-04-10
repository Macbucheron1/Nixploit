{ pkgs, lib, concatHistory, ... }:
{
  home.packages = lib.mkAfter (with pkgs; [
    nmap
    rustscan
  ]);

  my.histories.common = concatHistory "common-history" [
    ./history/nmap
    ./history/rustscan
  ];
}
