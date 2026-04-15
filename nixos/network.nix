{ lib, nixploit, ... }:
let
  inherit (nixploit.container) hostname;
in
{
  # allow  the unix group 100 to use ICMP socks
  boot.kernel.sysctl."net.ipv4.ping_group_range" = "100 100";

  networking = {
    nameservers = [ "8.8.8.8" "1.1.1.1" ];

    hostName = lib.mkDefault hostname;

    interfaces.eth0.useDHCP = lib.mkDefault true;
  };
  
  systemd.services.dhcpcd-var-run = {
    description = "Prepare /var/run for dhcpcd";
    requiredBy = [ "dhcpcd.service" ];
    before = [ "dhcpcd.service" ];
    serviceConfig.Type = "oneshot";
    script = ''
      if [ ! -e /var/run ]; then
        ln -s /run /var/run
      fi
      mkdir -p /run/dhcpcd
    '';
  };


}
