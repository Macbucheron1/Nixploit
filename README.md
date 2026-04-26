# Nixploit 

![demo](./asset/demo.gif)

## Prerequisite

1. Make sur **nix** is installed. See [related documentation](https://nixos.org/download/)
2. Make sur **incus** is installed. See [related documentation](https://linuxcontainers.org/incus/docs/main/installing/#installing)

## Quick start

1. Just launch it
```bash
nix run github:Macbucheron1/nixploit
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
    - [ ] Network
    - [ ] GUI
    - [ ] GPU
- [x] Add git 
- [ ] Make github pipeline to release the wrapper at each tag
- Talk about network options in the readme
- Talk about storage option in the readme

