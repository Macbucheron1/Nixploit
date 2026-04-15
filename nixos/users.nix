{ username, uid, gid, ... }:
{
  users.mutableUsers = false;

  # --- CHANGEME ---
  users.users.root.password = "root";
  # ----------------

  users.groups.${username}.gid = gid;

  users.users.${username} = {
    isNormalUser = true;
    uid = uid;
    group = username;

    # --- CHANGEME ---
    password = "user";
    # ----------------

    extraGroups = [ "wheel" "video" "render" ];
  };

  security.sudo.enable = true;
}
