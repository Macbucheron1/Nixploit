{ pkgs, lib, hostname ? "pentest", username ? "user", ... }:

{
  boot.isContainer = true;

  networking.hostName = lib.mkDefault hostname;

  networking.nameservers = [ "1.1.1.1" "1.0.0.1" ];

  users.mutableUsers = false;
  users.users.root.password = "root";
  users.users.${username} = {
    isNormalUser = true;
    password = "user";
    extraGroups = [ "wheel" ];
  };

  security.sudo.enable = true;

  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nix.settings.sandbox = false;
  systemd.services.nix-daemon-socket-dir = {
    description = "Prepare Nix daemon socket directory";
    wantedBy = [ "sockets.target" ];
    before = [
      "sockets.target"
      "nix-daemon.socket"
      "home-manager-user.service"
    ];
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

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" ];

  environment.systemPackages = with pkgs; [
    bashInteractive
    coreutils
    netexec
    firefox-bin
    burpsuite
  ];

  environment.variables = {
    DISPLAY = ":0";
    XAUTHORITY = "/mnt/.config/.Xauthority";
    WAYLAND_DISPLAY = "/mnt/.config/wayland-0";
    MOZ_ENABLE_WAYLAND = "1";
    GDK_BACKEND = "wayland";
  };

  systemd.services.x11-link = {
    description = "Prepare X11 socket link";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      mkdir -p /tmp/.X11-unix
      ln -sf /mnt/.config/.X11-unix/X0 /tmp/.X11-unix/X0
    '';
  };

  system.stateVersion = "25.05";
}
