package main

import (
	"crypto/sha256"
	"os"
	"fmt"
	"io"
)

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

