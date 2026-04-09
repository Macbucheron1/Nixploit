# Nixploit 

## Usage

1. Build the image 
```bash
incus image import ./result --alias nixploit
```

2. Load the image
```bash
incus launch nixploit <container_name> -p default -p pentest-gui
```

3. Open a shell
```bash
incus exec <container_name> login
```

## Shortcut

```
# When taping a command, will suggest autocompletion using fzf
alt tab


```
