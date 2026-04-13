{ pkgs, lib, concatHistory, ... }:
{
  home.packages = lib.mkAfter ((with pkgs; [
    netexec
    certipy
    responder
    krb5
    evil-winrm
    ldapmonitor
  ]) ++ (with pkgs.python313Packages; [
    bloodyad
    impacket
  ]));

  my.histories.activeDirectory = concatHistory "ad-history" [
    ./history/certipy
    ./history/netexec
    ./history/bloodyAD
    ./history/responder
    ./history/kerberos
    ./history/impacket
    ./history/evil-winrm
  ];
}
