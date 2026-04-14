{ pkgs, lib, concatHistory, ... }:
{
  home.packages = lib.mkAfter (with pkgs; [
    nmap
    rustscan
    ligolo-ng
    hashcat
    john
    metasploit
  ]);

  my.histories.common = concatHistory "common-history" [
    ./history/nmap
    ./history/rustscan
    ./history/ligolo-ng
    ./history/john-the-ripper
    ./history/metasploit
    ./history/hashcat
  ];

  imports = [
    ./firefox.nix 
    ./codex.nix
  ];
}
