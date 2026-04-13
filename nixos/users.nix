{ username, ... }:
{
  users.mutableUsers = false;

  # --- CHANGEME ---
  users.users.root.password = "root";
  # ----------------

  users.users.${username} = {
    isNormalUser = true;

    # --- CHANGEME ---
    password = "user";
    # ----------------

    extraGroups = [ "wheel" "video" "render" ];
  };

  security.sudo.enable = true;
}
