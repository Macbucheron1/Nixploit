{ pkgs, lib, nixploit, ... }:
let
  inherit (nixploit.container) hostname;
in
{
  networking = {
    hostName = lib.mkDefault hostname;
    useNetworkd = false;
    useDHCP = false;
    useHostResolvConf = true;
    interfaces.eth0.useDHCP = true;
  };

  services.resolved.enable = false;
  environment.etc."openvpn/update-resolv-conf".source = "${pkgs.update-resolv-conf}/libexec/openvpn/update-resolv-conf";
}
