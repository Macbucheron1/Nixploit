{ pkgs, ... }:
let
  runtimeDir = "/run/user/0";
in
{
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  environment.variables = {
    DISPLAY = ":100";
    XDG_RUNTIME_DIR = runtimeDir;
    _JAVA_AWT_WM_NONREPARENTING = "1";
  };

  environment.loginShellInit = ''
    export DISPLAY=:100
    export XDG_RUNTIME_DIR=${runtimeDir}

    if [ -n "$PS1" ] && [ "$PS1" = '\s-\v\$ ' ]; then
      export PS1='[\u@\h:\w]# '
    fi
  '';

  systemd.services.xpra = {
    description = "Xpra root session";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "sshd.service" ];
    path = [ pkgs.coreutils pkgs.xpra ];
    serviceConfig = {
      Type = "simple";
      User = "root";
      Restart = "on-failure";
      RestartSec = 2;
    };
    script = ''
      mkdir -p ${runtimeDir}
      chmod 700 ${runtimeDir}

      exec ${pkgs.xpra}/bin/xpra start :100 \
        --daemon=no \
        --mdns=no \
        --html=no
    '';
  };
}
