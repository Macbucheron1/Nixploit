{ pkgs, lib, ... }:
let
  mkCapWrapper = { pkg, bin, caps ? "" }: {
    owner = "root";
    group = "root";
    source = "${pkg}/bin/${bin}";
    capabilities = caps;
  };

  wrappers = {
    nmap = {
      pkg = pkgs.nmap;
      bin = "nmap";
      caps = "cap_net_raw,cap_net_admin+eip";
    };

    rustscan = {
      pkg = pkgs.rustscan;
      bin = "rustscan";
    };

    dumpcap = {
      pkg = pkgs.wireshark;
      bin = "dumpcap";
      caps = "cap_net_raw,cap_net_admin+eip";
    };
  };
in
{
  environment.variables.NMAP_PRIVILEGED = "1";
  security.wrappers = lib.mapAttrs (_: mkCapWrapper) wrappers;
}
