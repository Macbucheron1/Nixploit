{ nixpkgs, home-manager }:
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
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.extraSpecialArgs = {
        inherit username;
      };
      home-manager.users.${username} = import ../home;
    }
  ] ++ modules;
}
