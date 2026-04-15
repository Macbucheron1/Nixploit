{ nixploit, ... }:
let
  inherit (nixploit.container) username;
in
{
  # Make sur the nix daemon is started
  systemd.services.nix-daemon-socket-dir = {
    description = "Prepare Nix daemon socket directory";
    requiredBy = [ "nix-daemon.socket" ];
    before = [
      "nix-daemon.socket"
      "home-manager-user.service"
    ];
    after = [ "local-fs.target" ];
    unitConfig.DefaultDependencies = false;
    serviceConfig.Type = "oneshot";
    script = ''
      mkdir -p /nix/var/nix/daemon-socket
      chown root:root /nix/var/nix/daemon-socket
      chmod 0755 /nix/var/nix/daemon-socket
    '';
  };
  systemd.services."home-manager-${username}" = {
    requires = [
      "nix-daemon-socket-dir.service"
      "nix-daemon.socket"
    ];
    after = [
      "nix-daemon-socket-dir.service"
      "nix-daemon.socket"
      "nix-daemon.service"
    ];
    wants = [ "nix-daemon.socket" ];
  };
}
