package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/charmbracelet/log"
	"github.com/lxc/incus/v6/client"
	"github.com/lxc/incus/v6/shared/api"
)

func buildMetadata() (string, error) {
	log.Info("Building metadata, Should be quick...")
	nixBuildMetadataCmd := exec.Command("nix", "build", "..#metadata", "--print-out-paths", "--no-link")

	// Get a path like /nix/store/zid9hqq29ih3ycrdwmarm83q1zkgrasm-tarball
	metadataDir, err := nixBuildMetadataCmd.Output()
	if err != nil {
		log.Error("command failed", "err", err)
		return "", err
	}

	// Try to find the actual tarball located at /nix/store/...-tarball/tarball/*.tar.xz
	metadataDirStr := strings.TrimSpace(string(metadataDir))
	pattern := filepath.Join(string(metadataDirStr), "tarball/", "*.tar.xz")
	matches, err := filepath.Glob(pattern)
	if err != nil {
		log.Error(err)
		return "", err
	}
	if len(matches) == 0 {
		log.Error("No tarball found")
		return "", fmt.Errorf("No tarball found")
	}
	metadataPath := matches[0]
	
	log.Debug("Built metadata", "metadataPath", string(metadataPath))
	return metadataPath, nil
}

func buildSquashfs() (string, error) {
	log.Info("Building squashfs, can take some time...")
	nixBuildSquashfsCmd := exec.Command("nix", "build", "..#squashfs", "--print-out-paths", "--no-link")

	// Get a path like /nix/store/idi4d5hfy6yvhnbxvjfdhd201wl0ni0x-nixos-lxc-image-x86_64-linux
	squashfsDir, err := nixBuildSquashfsCmd.Output()
	if err != nil {
		log.Error("command failed", "err", err)
		return "", err
	}

	// Build the actual squashfs path
	squashfsDirStr := strings.TrimSpace(string(squashfsDir))
	squashfsPath := filepath.Join(string(squashfsDirStr), "/nixos-lxc-image-x86_64-linux.squashfs")
	log.Debug("Built squashfs", "squashfsPath", string(squashfsPath))
	return squashfsPath, nil
}

func importImage(metadataPath, squashfsPath, imageName string) error {
	// uses the default unix socket for incus
	log.Debug("Try to connect to the incus daemon")
	server, err := incus.ConnectIncusUnix("", nil)
	if err != nil {
		log.Error("Could not connect to incus socket")
		return err
	}
	log.Debug("Successfully connected to the incus daemon")

	// Open metadata
	metadataFile, err := os.Open(metadataPath)
	if err != nil {
		log.Error(fmt.Sprintf("Could not open medataFile: %s", err))
		return err
	}
	defer metadataFile.Close()

	// Open squashfs
	squashfsFile, err := os.Open(squashfsPath)
	if err != nil {
		log.Error(fmt.Sprintf("Could not open medataFile: %s", err))
		return err
	}
	defer squashfsFile.Close()

	// Prepare the information for incus API
	image := api.ImagesPost{
		Filename: filepath.Base(metadataPath),
		Aliases: []api.ImageAlias{{
			Name: imageName,
			Description: "A pentesting image based on nixos",
		}},
		ImagePut: api.ImagePut{
			AutoUpdate: false,
			Public: false,
			Properties: map[string]string{
				"os":          "NixOS",
				"variant":     "nixploit",
				"description": "A pentesting image based on nixos",
			},
		},
	}

	// Prepare the content of the image upload
	args := incus.ImageCreateArgs{
		MetaFile: metadataFile,
		MetaName: filepath.Base(metadataPath),
		RootfsFile: squashfsFile,
		RootfsName: filepath.Base(squashfsPath),
		Type: "container",
	}

	fingerprint, err := computeSplitImageFingerprint(metadataPath, squashfsPath)
	if err != nil {
		log.Error("Could not compute fingerprint", "err", err)
		return err
	}

	// If the image already exists, just add the name as an alias 
	img, _, err := server.GetImage(fingerprint)
	if err == nil {
		log.Debug("Image already exists", "fingerprint", img.Fingerprint)
		err = server.CreateImageAlias(api.ImageAliasesPost{ 
			ImageAliasesEntry: api.ImageAliasesEntry{
				Name: imageName,
				Type: "container",
				ImageAliasesEntryPut: api.ImageAliasesEntryPut{
					Target: fingerprint,
				},
			},
		})
		if err != nil {
			log.Warn("Could not create alias", "err", err)
		}
		return err
	}


	// Actually import the image
	log.Info("Importing the image")
	operation, err := server.CreateImage(image, &args)
	if err != nil {
		log.Error(fmt.Sprintf("Could not create the image: %s", err))
		return err
	}
	if err := operation.Wait(); err != nil {
		log.Error(fmt.Sprintf("While waiting for image upload: %s", err))
		return err
	}
	log.Info("Image ready to be used")
	return nil
}

func buildAction(imageName string) error {
	log.Debug("Building image", "imageName", imageName)

	metadataPath, err := buildMetadata()
	if err != nil {
		return err
	}
	log.Debug(metadataPath)
	squashfsPath, err := buildSquashfs()
	if err != nil {
		return err
	}
	log.Debug(squashfsPath)

	if metadataPath == "" || squashfsPath == "" {
		log.Error("Could not build the image")
		return fmt.Errorf("Could not build the image")
	}

	err = importImage(metadataPath, squashfsPath, imageName)
	if err != nil {
		return err
	}
	log.Info("Image buildt and imported successfully")
	return nil
}
