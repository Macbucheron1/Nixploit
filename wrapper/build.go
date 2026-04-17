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

func buildMetadata() string {
	log.Info("Building metadata, Should be quick...")
	nixBuildMetadataCmd := exec.Command("nix", "build", "..#metadata", "--print-out-paths")

	// Get a path like /nix/store/zid9hqq29ih3ycrdwmarm83q1zkgrasm-tarball
	metadataDir, err := nixBuildMetadataCmd.Output()
	if err != nil {
		log.Error("command failed", "err", err)
		return ""
	}

	// Try to find the actual tarball located at /nix/store/...-tarball/tarball/*.tar.xz
	metadataDirStr := strings.TrimSpace(string(metadataDir))
	pattern := filepath.Join(string(metadataDirStr), "tarball/", "*.tar.xz")
	matches, err := filepath.Glob(pattern)
	if err != nil {
		log.Error(err)
	}
	if len(matches) == 0 {
		log.Error("No tarball found")
	}
	metadataPath := matches[0]
	
	log.Debug("Built metadata", "metadataPath", string(metadataPath))
	return metadataPath
}

func buildSquashfs() string {
	log.Info("Building squashfs, can take some time...")
	nixBuildSquashfsCmd := exec.Command("nix", "build", "..#squashfs", "--print-out-paths")

	// Get a path like /nix/store/idi4d5hfy6yvhnbxvjfdhd201wl0ni0x-nixos-lxc-image-x86_64-linux
	squashfsDir, err := nixBuildSquashfsCmd.Output()
	if err != nil {
		log.Error("command failed", "err", err)
		return ""
	}

	// Build the actual squashfs path
	squashfsDirStr := strings.TrimSpace(string(squashfsDir))
	squashfsPath := filepath.Join(string(squashfsDirStr), "/nixos-lxc-image-x86_64-linux.squashfs")
	log.Debug("Built squashfs", "squashfsPath", string(squashfsPath))
	return squashfsPath
}

func importImage(metadataPath, squashfsPath, imageName string) {
	// uses the default unix socket for incus
	log.Debug("Try to connect to the incus daemon")
	server, err := incus.ConnectIncusUnix("", nil)
	if err != nil {
		log.Error("Could not connect to incus socket")
		return
	}
	log.Debug("Successfully connected to the incus daemon")

	// Open metadata
	metadataFile, err := os.Open(metadataPath)
	if err != nil {
		log.Error(fmt.Sprintf("Could not open medataFile: %s", err))
	}
	defer metadataFile.Close()

	// Open squashfs
	squashfsFile, err := os.Open(squashfsPath)
	if err != nil {
		log.Error(fmt.Sprintf("Could not open medataFile: %s", err))
	}
	defer squashfsFile.Close()

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

	args := incus.ImageCreateArgs{
		MetaFile: metadataFile,
		MetaName: filepath.Base(metadataPath),
		RootfsFile: squashfsFile,
		RootfsName: filepath.Base(squashfsPath),
		Type: "container",
	}

	if !server.HasExtension("image_create_aliases"){
		log.Warn("Incus server does not support image_create_aliases")
	}

	log.Debug("Importing the image")
	operation, err := server.CreateImage(image, &args)
	if err != nil {
		log.Error(fmt.Sprintf("Could not create the image: %s", err))
		return
	}
	if err := operation.Wait(); err != nil {
		log.Error(fmt.Sprintf("While waiting for image upload: %s", err))
		return
	}
	log.Info("Image created")
}

func build(imageName string) {
	log.Debug("Building image", "imageName", imageName)

	metadataPath := buildMetadata()
	log.Debug(metadataPath)
	squashfsPath := buildSquashfs()
	log.Debug(squashfsPath)

	if metadataPath == "" || squashfsPath == "" {
		log.Error("Could not build the image")
		return 
	}

	importImage(metadataPath, squashfsPath, imageName)
}
