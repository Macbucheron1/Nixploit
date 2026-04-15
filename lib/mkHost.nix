inputs:
{
  system,
  nixploit,
  modules ? [ ],
  specialArgs ? { },
}:
inputs.nixpkgs.lib.nixosSystem {
  inherit system;
  specialArgs = specialArgs // {
    inherit nixploit;
    inherit (inputs) redflake-packages neo4j44pkgs firefox-addons;
  };
  modules = [
    ../nixos
    inputs.home-manager.nixosModules.home-manager
    inputs.nur.modules.nixos.default
    inputs.stylix.nixosModules.stylix
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.extraSpecialArgs = {
        inherit nixploit;
        inherit (inputs) mac-nixos firefox-addons;
      };
      nixpkgs.overlays = [ inputs.nur.overlays.default ];
      home-manager.users.${nixploit.container.username} = {
        imports = [
          ../home
          inputs.burpsuite-nix.homeManagerModules.default
        ];
      };
    }
  ] ++ modules;
}
