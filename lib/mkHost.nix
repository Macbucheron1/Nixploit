{ nixpkgs, home-manager, nur, stylix, burpsuite-nix, mac-nixos, redflake-packages, neo4j44pkgs, firefox-addons }:
{
  system,
  hostname,
  username,
  uid,
  gid,
  modules ? [ ],
  specialArgs ? { },
}:
nixpkgs.lib.nixosSystem {
  inherit system;
  specialArgs = specialArgs // {
    inherit hostname username uid gid redflake-packages neo4j44pkgs firefox-addons;
  };
  modules = [
    ../nixos
    home-manager.nixosModules.home-manager
    nur.modules.nixos.default
    stylix.nixosModules.stylix
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.extraSpecialArgs = {
        inherit username mac-nixos firefox-addons;
      };
      nixpkgs.overlays = [ nur.overlays.default ];
      home-manager.users.${username} = {
        imports = [
          ../home
          burpsuite-nix.homeManagerModules.default
        ];
      };
    }
  ] ++ modules;
}
