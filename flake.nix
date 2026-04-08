{
  description = "Minimal OCI image with netexec and container-ready Burp Suite";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    home-manager,
    nixpkgs,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
    burpsuite = pkgs.callPackage ./pkgs/burpsuite-container.nix { };
    homeConfig = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [ ./home/default.nix ];
    };
    homeProfile = homeConfig.config.home.path;
    homeFiles = "${homeConfig.activationPackage}/home-files";
  in {
    packages.${system}.default = pkgs.dockerTools.buildLayeredImage {
      name = "minimal-netexec";
      tag = "latest";

      contents = [
        pkgs.bashInteractive
        pkgs.coreutils
        burpsuite
        pkgs.firefox-bin
        pkgs.netexec
        pkgs.fontconfig
        pkgs.dejavu_fonts
        pkgs.dbus
      ];

      extraCommands = ''
        mkdir -p etc
        echo 'root:x:0:0:root:/root:/bin/bash' > etc/passwd
        echo 'root:x:0:' > etc/group
        echo '87c4bc1848a84471997203ee530d2fda' > etc/machine-id
        mkdir -p root
        cp -a ${homeFiles}/. root/
        mkdir -p /tmp/firefox-clean
        chmod 700 /tmp/firefox-clean
      '';

      config = {
        Env = [
          "HOME=/root"
          "USER=root"
          "PATH=${homeProfile}/bin:/bin"
          "FONTCONFIG_FILE=${pkgs.fontconfig.out}/etc/fonts/fonts.conf"
          # "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
        ];
        WorkingDir = "/root";
        Cmd = [ "${pkgs.bashInteractive}/bin/bash" ];
      };
    };
  };
}
