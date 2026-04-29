package main

import (
	"crypto/sha256"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"

	"github.com/charmbracelet/huh"
	"github.com/charmbracelet/log"
	"github.com/lxc/incus/v6/client"
	"github.com/lxc/incus/v6/shared/api"
)

var (
	server    incus.InstanceServer
	serverErr error
	once      sync.Once
)

// Get the directory used to store nixploit assets on the host
func nixploitDir() (string, error) {
	if xdgDataHome := os.Getenv("XDG_DATA_HOME"); xdgDataHome != "" {
		return filepath.Join(xdgDataHome, "nixploit"), nil
	}

	home, err := os.UserHomeDir()
	if err != nil {
		return "", fmt.Errorf("get user home dir: %w", err)
	}

	return filepath.Join(home, ".local", "share", "nixploit"), nil
}

// Get the directory used to store nixploit git repositories on the host
func nixploitGitDir() (string, error) {
	dir, err := nixploitDir()
	if err != nil {
		return "", err
	}

	return filepath.Join(dir, "git"), nil
}

// Get the directory used to store nixploit ssh assets on the host
func nixploitSshDir() (string, error) {
	dir, err := nixploitDir()
	if err != nil {
		return "", err
	}

	return filepath.Join(dir, "ssh"), nil
}

// Open a unix socket to the incus server but only once
func getIncusServer() (incus.InstanceServer, error) {
	// Only execute once
	once.Do(func() {
		log.Debug("Connecting for the first time")
		server, serverErr = incus.ConnectIncusUnix("", nil)
	})
	return server, serverErr
}

// Ask Yes or no in a nice TUI way
func askYesNo(title string) (bool, error) {
	var confirmed bool

	form := huh.NewForm(
		huh.NewGroup(
			huh.NewConfirm().
				Title(title).
				Affirmative("Yes").
				Negative("No").
				Value(&confirmed),
		),
	)

	if err := form.Run(); err != nil {
		return false, err
	}

	return confirmed, nil
}

// Get the current container state
// Possible state: Running, Stopped, Frozen or Error
// return an error if the container does not exist
func getContainerState(containerName string) (string, error) {
	// Connect to the incus daemon
	log.Debug("Try to connect to the incus daemon")
	server, err := getIncusServer()
	if err != nil {
		log.Error("Could not connect to incus socket")
		return "", err
	}
	log.Debug("Successfully connected to the incus daemon")

	log.Debugf("Getting %s state", containerName)
	state, _, err := server.GetInstanceState(containerName)
	if err != nil {
		log.Errorf("While getting %s state: %s", containerName, err)
		return "", err
	}
	log.Debugf("%s state is %s", containerName, state.Status)
	return state.Status, nil
}

// Set the container to the selected state
// Possible state: start, stop, restart, freeze, unfreeze
// return an error if the container does not exist
func setContainerState(containerName, newState string) error {
	// Connect to the incus daemon
	log.Debug("Try to connect to the incus daemon")
	server, err := getIncusServer()
	if err != nil {
		log.Error("Could not connect to incus socket")
		return err
	}
	log.Debug("Successfully connected to the incus daemon")

	log.Debug("Updating container's state")
	operation, err := server.UpdateInstanceState(containerName, api.InstanceStatePut{
		Action:   newState,
		Timeout:  10,
		Force:    false,
		Stateful: false,
	}, "")
	if err := operation.Wait(); err != nil {
		log.Errorf("While waiting to update container state to %s: %s", newState, err)
		return err
	}
	return nil
}

// Compute the Fingerprint of an image without importing it to incus
func computeSplitImageFingerprint(metadataPath, squashfsPath string) (string, error) {
	h := sha256.New()

	metaFile, err := os.Open(metadataPath)
	if err != nil {
		return "", fmt.Errorf("open metadata: %w", err)
	}
	defer metaFile.Close()

	if _, err := io.Copy(h, metaFile); err != nil {
		return "", fmt.Errorf("hash metadata: %w", err)
	}

	rootfsFile, err := os.Open(squashfsPath)
	if err != nil {
		return "", fmt.Errorf("open rootfs: %w", err)
	}
	defer rootfsFile.Close()

	if _, err := io.Copy(h, rootfsFile); err != nil {
		return "", fmt.Errorf("hash rootfs: %w", err)
	}

	return fmt.Sprintf("%x", h.Sum(nil)), nil
}

// Check if there is an image with this name is the incus storage
func imageExistInIncus(imageName string) (bool, error) {
	log.Debugf("Checking if %s's image is uploaded", imageName)

	// Connect to the incus daemon
	log.Debug("Try to connect to the incus daemon")
	server, err := getIncusServer()
	if err != nil {
		log.Error("Could not connect to incus socket")
		return false, err
	}
	log.Debug("Successfully connected to the incus daemon")

	// Check if image exist
	if _, _, err = server.GetImageAlias(imageName); err != nil {
		if strings.Contains(err.Error(), "Image alias not found") {
			return false, nil
		}
		log.Warn(fmt.Sprintf("While checking if image exist: %s", err))
		return false, err
	}
	return true, nil
}

// Check if a file exist
func fileExist(containerName, filePath string) (bool, error) {
	log.Debugf("Checking if %s file is on %s container", filePath, containerName)

	// Connect to the incus daemon
	log.Debug("Try to connect to the incus daemon")
	server, err := getIncusServer()
	if err != nil {
		log.Error("Could not connect to incus socket")
		return false, err
	}
	log.Debug("Successfully connected to the incus daemon")

	_, _, err = server.GetInstanceFile(containerName, filePath)

	if err != nil {
		if strings.Contains(err.Error(), "Not Found") {
			return false, nil
		}
		log.Debugf("While checking if %s file exist: %s", filePath, err)
		return false, err
	}

	return true, nil
}

// Create the nixploit directory to store assets
func createNixploitDir() error {
	dir, err := nixploitDir()
	if err != nil {
		log.Errorf("While getting nixploit dir: %s", err)
		return err
	}
	log.Debugf("Creating the nixploit dir at %s", dir)

	if err := os.MkdirAll(dir, 0700); err != nil {
		log.Errorf("While creating the nixploit dir: %s", err)
		return err
	}

	sshDir, err := nixploitSshDir()
	if err != nil {
		log.Errorf("While getting nixploit ssh directory: %s", err)
		return err
	}
	if err := os.MkdirAll(sshDir, keyDirPerm); err != nil {
		log.Errorf("While creating ssh key directory: %s", err)
		return err
	}

	gitDir, err := nixploitGitDir()
	if err != nil {
		log.Errorf("While getting nixploit git directory: %s", err)
		return err
	}
	if err := os.MkdirAll(gitDir, keyDirPerm); err != nil {
		log.Errorf("While creating the git directory: %s", err)
		return err
	}

	return nil
}

// Clone the Nixploit repository into the nixploit git directory
func cloneNixploitRepo() error {
	log.Debug("Cloning the repository")

	gitDir, err := nixploitGitDir()
	if err != nil {
		log.Errorf("While getting nixploit git directory: %s", err)
		return err
	}

	if err := os.MkdirAll(gitDir, 0700); err != nil {
		log.Errorf("While creating the git directory: %s", err)
		return err
	}

	gitMetadataDir := filepath.Join(gitDir, ".git")
	if info, err := os.Stat(gitMetadataDir); err == nil {
		if !info.IsDir() {
			return fmt.Errorf("nixploit git metadata path exists but is not a directory: %s", gitMetadataDir)
		}

		log.Debugf("Nixploit repository already exists at %s", gitDir)
		return nil
	} else if !os.IsNotExist(err) {
		log.Errorf("While checking nixploit git metadata directory: %s", err)
		return err
	}

	log.Debugf("Cloning Nixploit repository into %s", gitDir)

	cmd := exec.Command(
		"git",
		"clone",
		"git@github.com:Macbucheron1/Nixploit.git",
		".",
	)

	cmd.Dir = gitDir

	output, err := cmd.CombinedOutput()
	if err != nil {
		log.Errorf("While cloning Nixploit repository: %s", strings.TrimSpace(string(output)))
		return fmt.Errorf("git clone Nixploit: %w", err)
	}

	log.Debugf("Nixploit repository cloned into %s", gitDir)
	return nil
}
