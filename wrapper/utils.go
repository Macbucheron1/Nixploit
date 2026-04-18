package main

import (
	"crypto/sha256"
	"fmt"
	"io"
	"os"
	"sync"
	"strings"

	"github.com/charmbracelet/log"
	"github.com/lxc/incus/v6/client"
	"github.com/charmbracelet/huh"
)

var (
	server    incus.InstanceServer
	serverErr error
	once      sync.Once
)

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
func imageExistInIncus (imageName string) (bool, error) {
	log.Debug(fmt.Sprintf("Checking if %s's image is uploaded", imageName))

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
		if strings.Contains(err.Error(), "Image alias not found"){
			return false, nil
		}
		log.Warn(fmt.Sprintf("While checking if image exist: %s", err))
		return false, err
	}
	return true, nil
}
