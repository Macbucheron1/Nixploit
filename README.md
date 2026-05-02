# Nixploit 

![demo](./asset/demo.gif)

## Prerequisite

> [!CAUTION]
> This was not only tested on nixos but _should_ work on any distribution with the prerequisite

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

## What & Why

### Problem
TODO

### Nix
TODO

### Incus
TODO

### Golang
TODO

## TODO

### Wrapper
- [ ] Fix multiple TODO in wrapper
    - [x] Network
    - [ ] GUI
    - [ ] GPU
- [ ] Make it possible to update profile while container is running
- [x] Generate ssh using ssh.go and copy it in the container. Be careful wheter the key already exist, still check if the key is in the container
- [ ] Launch xpra through the wrapper
### Image
- [x] Add git 
### Docs 
- [ ] Talk about storage option in the readme
- [ ] Talk about network options in the readme (allow firewall for the nixploit network to use dhcp port)
### Other
- [ ] Make github pipeline to release the wrapper at each tag
- [ ] Test on other distribution with nix installed
### Security 
- [ ] use a passphrase for the ssh key
- [ ] XPRA host key checking ? check how they do on mofos
- [ ] network put none by default 
- [ ] use a different bridge for each 
- [ ] make sur ipv6 Router Advertisement is disabled on nixploit network
    - https://linuxcontainers.org/incus/docs/main/explanation/security/#bridged-nic-security
- [ ] Disallow BPF
    - https://linuxcontainers.org/incus/docs/main/explanation/bpf-tokens/
