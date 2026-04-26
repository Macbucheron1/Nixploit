# Nixploit 

![demo](./asset/demo.gif)

## Prerequisite

1. Make sure **nix** is installed. See [related documentation](https://nixos.org/download/)
2. Make sure **incus** is installed. See [related documentation](https://linuxcontainers.org/incus/docs/main/installing/#installing)

## Quick start

```bash
# Clone the repository
git clone https://github.com/Macbucheron1/Nixploit.git

# Just launch the damn thing
cd Nixploit
nix run .
```

## Developpement setup

```bash
# Clone the repository
git clone https://github.com/Macbucheron1/Nixploit.git

# Enter the repository
cd Nixploit

# if you use direnv 
# direnv allow
# Otherwise
nix develop
```

## TODO

- [ ] Fix multiple TODO in wrapper
    - [x] Network
    - [ ] GUI
    - [ ] GPU
- [x] Add git 
- [ ] Make github pipeline to release the wrapper at each tag
- [ ] Talk about network options in the readme (allow firewall for the nixploit network to use dhcp port)
- [ ] Talk about storage option in the readme
- [ ] Make it possible to update profile while container is running
- [ ] Test on other distribution with nix installed

