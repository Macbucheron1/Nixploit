{ lib, nixploit, ... }:
let
  inherit (nixploit.container) hostname;
in
{
  networking = {
    hostName = lib.mkDefault hostname;
    useNetworkd = true;
    useHostResolvConf = false;
    nameservers = [ "8.8.8.8" "1.1.1.1" ];
  };

  services.resolved.enable = false;

  systemd.network.enable = true;
  systemd.network.networks."10-eth0" = {
    matchConfig.Name = "eth0";
    address = [ "10.58.55.250/24" ];
    routes = [
      { Gateway = "10.58.55.1"; }
    ];
    networkConfig = {
      IPv6AcceptRA = true;
    };
  };
}
