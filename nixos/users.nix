{ nixploit, ... }:
let
  inherit (nixploit.container) rootPassword;
in
{
  users.mutableUsers = false;
  users.users.root.password = rootPassword;
}
