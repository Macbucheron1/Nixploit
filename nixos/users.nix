{ username, ... }:
{
  users.mutableUsers = false;
  users.users.root.password = "root";
  users.users.${username} = {
    isNormalUser = true;
    password = "user";
    extraGroups = [ "wheel" ];
  };

  security.sudo.enable = true;
}
