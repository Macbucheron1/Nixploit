package main

import (
	"fmt"
	"os/exec"
	"path"
	"time"

	"github.com/charmbracelet/log"
	"github.com/lxc/incus/v6/shared/api"
)

func xpraConnect (containerName string) error {
	log.Debug("Connecting to the xpra server")

	if !isXpraThere() {
		return fmt.Errorf("Could not find xpra binary")
	}

	// TODO: find ip address (make sur it is the nixploit-bridge one)
	// connect to the incus server
	log.Debug("Try to connect to the incus daemon")
	server, err := getIncusServer()
	if err != nil {
		log.Error("Could not connect to incus socket")
		return err
	}
	log.Debug("Successfully connected to the incus daemon")

	log.Debug("Getting instance state")
	var eth0 api.InstanceStateNetworkAddress
	for i := range 20 {
		state, _, err := server.GetInstanceState(containerName)
		if err != nil {
			log.Debugf("While getting state instance: %s", err.Error())
			return err
		}

		eth0 = state.Network["eth0"].Addresses[0]
		if eth0.Family == "inet" {
			log.Debugf("Found ip %s for eth0 in %s container", eth0.Address, containerName)
			break
		} else if i == 19 {
			log.Debug("Could not find ipv4 address at eth0")
			return fmt.Errorf("Could not find ipv4 address at eth0, only found: %s", eth0.Address)
		}
		log.Debug("No ipv4 found at eth0, retrying...")
		time.Sleep(time.Second)
	}

	// Creating the ssh command to connect to the container
	sshKeyDir, err := sshKeyDir();
	if err != nil {
		return err
	}
	privateKeyPath := path.Join(sshKeyDir, "key")
	sshCmd := fmt.Sprintf(
		"ssh -i %s -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null",
		privateKeyPath,
	)

	// Preparing the command
	// TODO: use unix socket through incus proxy
	args := []string{
		"attach",
		fmt.Sprintf("ssh://root@%s/100", eth0.Address),
		"--ssh",
		sshCmd,
		"--printing=no",
		"--speaker=no",
		"--microphone=no",
		"--file-transfer=no",
		"--mdns=no",
		"--sharing=no",
		"--lock=yes",
		"--audio=no",
		"--reconnect=no",
		"--splash=no",
	}
	cmd := exec.Command("xpra", args...)
	cmd.Stdin = nil
	cmd.Stdout = nil
	cmd.Stderr = nil

	log.Debugf("Attaching to xpra session on container %s", containerName)

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("xpra attach failed: %s", err.Error())
	}

	//TODO: try to handle better the end of life. Currently just let if fail after deconnection

	return nil
}

