package main

import (
	"bytes"
	"crypto/ed25519"
	"encoding/pem"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/charmbracelet/log"
	incus "github.com/lxc/incus/v6/client"
	"golang.org/x/crypto/ssh"
)

const (
	keyDirPerm     = 0o700
	privateKeyPerm = 0o600
	publicKeyPerm  = 0o644
)

// Check if the nixploit data directory exists and is a directory
func nixploitDirExists() (bool, error) {
	dir, err := nixploitDir()
	if err != nil {
		return false, err
	}

	info, err := os.Stat(dir)
	if err != nil {
		if os.IsNotExist(err) {
			return false, nil
		}
		return false, fmt.Errorf("stat nixploit dir: %w", err)
	}

	if !info.IsDir() {
		return false, fmt.Errorf("nixploit path exists but is not a directory: %s", dir)
	}

	return true, nil
}

// Get the directory used to store nixploit ssh assets on the host
func sshKeyDir() (string, error) {
	return nixploitSshDir()
}

// Generate an unencrypted Ed25519 SSH key pair for nixploit
func GenerateSSHKeyPair(keyName string) (privateKeyPath string, publicKeyPath string, err error) {
	log.Debugf("Trying to generate ssh key pair %s", keyName)

	if keyName == "" {
		log.Error("The ssh key name is empty")
		return "", "", errors.New("key name cannot be empty")
	}

	if filepath.Base(keyName) != keyName {
		log.Error("The ssh key name is not a file name")
		return "", "", errors.New("key name must be a file name, not a path")
	}

	dir, err := sshKeyDir()
	if err != nil {
		log.Errorf("While getting ssh key directory: %s", err)
		return "", "", err
	}
	log.Debugf("Ssh assets will be stored in %s", dir)

	if err := os.MkdirAll(dir, keyDirPerm); err != nil {
		log.Errorf("While creating ssh key directory: %s", err)
		return "", "", fmt.Errorf("create ssh key directory: %w", err)
	}

	if err := os.Chmod(dir, keyDirPerm); err != nil {
		log.Errorf("While setting ssh key directory permissions: %s", err)
		return "", "", fmt.Errorf("chmod ssh key directory: %w", err)
	}

	info, err := os.Lstat(dir)
	if err != nil {
		log.Errorf("While checking ssh key directory: %s", err)
		return "", "", fmt.Errorf("stat ssh key directory: %w", err)
	}
	if !info.IsDir() {
		log.Error("The ssh key path is not a directory")
		return "", "", fmt.Errorf("ssh key path exists but is not a directory: %s", dir)
	}
	if info.Mode()&os.ModeSymlink != 0 {
		log.Error("The ssh key directory is a symlink")
		return "", "", fmt.Errorf("ssh key directory must not be a symlink: %s", dir)
	}

	privateKeyPath = filepath.Join(dir, keyName)
	publicKeyPath = privateKeyPath + ".pub"
	log.Debugf("Private key path: %s", privateKeyPath)
	log.Debugf("Public key path: %s", publicKeyPath)

	publicKey, privateKey, err := ed25519.GenerateKey(nil)
	if err != nil {
		log.Errorf("While generating ed25519 key pair: %s", err)
		return "", "", fmt.Errorf("generate ed25519 key: %w", err)
	}

	privatePEM, err := ssh.MarshalPrivateKey(privateKey, "nixploit")
	if err != nil {
		log.Errorf("While marshalling private ssh key: %s", err)
		return "", "", fmt.Errorf("marshal private key: %w", err)
	}

	privateBytes := pem.EncodeToMemory(privatePEM)
	if privateBytes == nil {
		log.Error("Could not encode private key to PEM")
		return "", "", errors.New("encode private key PEM")
	}

	sshPublicKey, err := ssh.NewPublicKey(publicKey)
	if err != nil {
		log.Errorf("While marshalling public ssh key: %s", err)
		return "", "", fmt.Errorf("marshal public key: %w", err)
	}

	publicBytes := ssh.MarshalAuthorizedKey(sshPublicKey)

	if err := writeFileExclusive(privateKeyPath, privateBytes, privateKeyPerm); err != nil {
		log.Errorf("While writing private ssh key: %s", err)
		return "", "", fmt.Errorf("write private key: %w", err)
	}

	if err := writeFileExclusive(publicKeyPath, publicBytes, publicKeyPerm); err != nil {
		log.Errorf("While writing public ssh key: %s", err)
		return "", "", fmt.Errorf("write public key: %w", err)
	}

	log.Debug("Ssh key pair generated successfully")
	return privateKeyPath, publicKeyPath, nil
}

func writeFileExclusive(path string, data []byte, perm os.FileMode) error {
	log.Debugf("Writing %s", path)
	file, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, perm)
	if err != nil {
		if os.IsExist(err) {
			log.Warnf("%s already exists", path)
			return fmt.Errorf("file already exists: %s", path)
		}
		log.Errorf("While opening %s: %s", path, err)
		return err
	}

	committed := false
	defer func() {
		_ = file.Close()
		if !committed {
			_ = os.Remove(path)
		}
	}()

	if _, err := file.Write(data); err != nil {
		log.Errorf("While writing %s: %s", path, err)
		return err
	}

	if err := file.Sync(); err != nil {
		log.Errorf("While syncing %s: %s", path, err)
		return err
	}

	if err := file.Close(); err != nil {
		log.Errorf("While closing %s: %s", path, err)
		return err
	}

	committed = true
	log.Debugf("%s written successfully", path)
	return nil
}

func sshKeyExists(path string) (bool, error) {
	log.Debugf("Checking if ssh key file exists at %s", path)
	info, err := os.Stat(path)
	if err != nil {
		if os.IsNotExist(err) {
			log.Debugf("Ssh key file does not exist at %s", path)
			return false, nil
		}
		log.Errorf("While checking ssh key file %s: %s", path, err)
		return false, err
	}

	if info.IsDir() {
		log.Errorf("Ssh key path is a directory: %s", path)
		return false, fmt.Errorf("ssh key path is a directory: %s", path)
	}

	log.Debugf("Ssh key file exists at %s", path)
	return true, nil
}

func ensureSSHKeyPair(keyName string) (privateKeyPath string, publicKeyPath string, err error) {
	log.Debugf("Ensuring ssh key pair %s exists", keyName)

	dir, err := sshKeyDir()
	if err != nil {
		log.Errorf("While getting ssh key directory: %s", err)
		return "", "", err
	}

	privateKeyPath = filepath.Join(dir, keyName)
	publicKeyPath = privateKeyPath + ".pub"

	privateKeyExists, err := sshKeyExists(privateKeyPath)
	if err != nil {
		return "", "", err
	}

	publicKeyExists, err := sshKeyExists(publicKeyPath)
	if err != nil {
		return "", "", err
	}

	if privateKeyExists && publicKeyExists {
		log.Debugf("Reusing existing ssh key pair %s", keyName)
		return privateKeyPath, publicKeyPath, nil
	}

	if privateKeyExists || publicKeyExists {
		log.Errorf("Incomplete ssh key pair %s: private=%t public=%t", keyName, privateKeyExists, publicKeyExists)
		return "", "", fmt.Errorf("incomplete ssh key pair %s", keyName)
	}

	log.Debugf("Ssh key pair %s does not exist, generating it", keyName)
	return GenerateSSHKeyPair(keyName)
}

func addSshKey(containerName string) error {
	log.Debug("Adding ssh key to the container")

	privateKeyPath, publicKeyPath, err := ensureSSHKeyPair("key")
	if err != nil {
		log.Errorf("While ensuring ssh key pair: %s", err)
		return err
	}

	log.Debugf("SSH private key available at %s", privateKeyPath)
	log.Debugf("SSH public key available at %s", publicKeyPath)

	publicKeyContent, err := os.ReadFile(publicKeyPath)
	if err != nil {
		log.Errorf("While reading public ssh key: %s", err)
		return err
	}

	// connect to the incus server
	log.Debug("Try to connect to the incus daemon")
	server, err := getIncusServer()
	if err != nil {
		log.Error("Could not connect to incus socket")
		return err
	}
	log.Debug("Successfully connected to the incus daemon")

	log.Debug("Creating /root/.ssh directory in the container")
	for i := range 10 {
		err = server.CreateInstanceFile(containerName, "/root/.ssh", incus.InstanceFileArgs{
			Content:   strings.NewReader(""),
			UID:       0,
			GID:       0,
			Mode:      0700,
			Type:      "directory",
			WriteMode: "overwrite",
		})
		if err != nil {
			if !strings.Contains(err.Error(), "Not Found") || i == 9 {
				log.Errorf("While creating /root/.ssh directory: %s", err)
				return err
			} else {
				log.Debug("Container not ready yet, retrying...")
				time.Sleep(time.Second)
			}
		}
	}

	log.Debug("Adding public ssh key to /root/.ssh/authorized_keys")
	for i := range 10 {
		err = server.CreateInstanceFile(containerName, "/root/.ssh/authorized_keys", incus.InstanceFileArgs{
			Content:   bytes.NewReader(publicKeyContent),
			UID:       0,
			GID:       0,
			Mode:      0600,
			Type:      "file",
			WriteMode: "overwrite",
		})
		if err != nil {
			if !strings.Contains(err.Error(), "Not Found") || i == 9 {
				log.Errorf("While adding public ssh key to authorized_keys: %s", err)
				return err
			}
			log.Debug("Container not ready, retrying...")
			time.Sleep(time.Second)
		}
	}

	log.Debug("Successfully added ssh key to the container")
	return nil
}
