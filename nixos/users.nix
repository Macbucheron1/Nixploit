{ nixploit, ... }:
let
  inherit (nixploit.container) username uid gid password rootPassword;
in
{
  users.mutableUsers = false;

  # --- CHANGEME ---
  users.users.root.password = rootPassword;
  # ----------------

  users.groups.${username}.gid = gid;

  users.users.${username} = {
    isNormalUser = true;
    uid = uid;
    group = username;

    # --- CHANGEME ---
    password = password;
    # ----------------

    extraGroups = [ "wheel" "video" "render" ];
  };

  security.sudo.enable = true;
}
