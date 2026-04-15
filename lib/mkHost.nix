{ nixpkgs, home-manager, nur, stylix, burpsuite-nix, mac-nixos, redflake-packages, neo4j44pkgs, firefox-addons }:
{
  system,
  nixploit,
  modules ? [ ],
  specialArgs ? { },
}:
nixpkgs.lib.nixosSystem {
  inherit system;
  specialArgs = specialArgs // {
    inherit nixploit redflake-packages neo4j44pkgs firefox-addons;
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
        inherit nixploit mac-nixos firefox-addons;
      };
      nixpkgs.overlays = [ nur.overlays.default ];
      home-manager.users.${nixploit.container.username} = {
        imports = [
          ../home
          burpsuite-nix.homeManagerModules.default
        ];
      };
    }
  ] ++ modules;
}
