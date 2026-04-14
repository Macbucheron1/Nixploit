{ lib, hostname, ... }:
{
  # allow  the unix group 100 to use ICMP socks
  boot.kernel.sysctl."net.ipv4.ping_group_range" = "100 100";


  networking.hostName = lib.mkDefault hostname;

  networking.interfaces.eth0.useDHCP = lib.mkDefault true;

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
