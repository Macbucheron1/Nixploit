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

    extraGroups = [ "wheel" ];
  };

  security.sudo.enable = true;
}
