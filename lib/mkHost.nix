{ nixpkgs, home-manager, nur, stylix, burpsuite-nix, mac-nixos }:
{
  system,
  hostname,
  username,
  modules ? [ ],
  specialArgs ? { },
}:
nixpkgs.lib.nixosSystem {
  inherit system;
  specialArgs = specialArgs // {
    inherit hostname username;
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
        inherit username mac-nixos;
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
