{ lib, nixploit, ... }:
let
  inherit (nixploit.container) hostname;
in
{
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
