{ pkgs, lib, ... }:

{
  boot.isContainer = true;

  networking.hostName = "pentest";

  networking.nameservers = [ "1.1.1.1" "1.0.0.1" ];

  users.mutableUsers = false;
  users.users.root.password = "root";
  users.users.user = {
    isNormalUser = true;
    password = "user";
  };

  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nix.settings.sandbox = false;

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" ];

  environment.systemPackages = with pkgs; [
    bashInteractive
    coreutils
    netexec
    firefox-bin
    zellij
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
