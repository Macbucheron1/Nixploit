{ lib, nixploit, ... }:
let
  inherit (nixploit.container) hostname;
in
{
  networking = {
    hostName = lib.mkDefault hostname;
    useNetworkd = false;
    useDHCP = false;
    useHostResolvConf = false;
    interfaces.eth0.useDHCP = true;
  };

  services.resolved.enable = false;
}
