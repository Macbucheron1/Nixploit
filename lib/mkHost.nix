{ nixpkgs, home-manager, nur, burpsuite-nix }:
{
  system,
  hostname ? "pentest",
  username ? "user",
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
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.extraSpecialArgs = {
        inherit username;
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
