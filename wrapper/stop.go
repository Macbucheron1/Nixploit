package main

import (
	"strings"

	"github.com/charmbracelet/log"
	"github.com/lxc/incus/v6/shared/api"
)

// Stop the container named containerName
func stopAction(containerName string) error {
	log.Infof("Stopping container named %s", containerName)

	// Connect to the incus daemon
	log.Debug("Try to connect to the incus daemon")
	server, err := getIncusServer()
	if err != nil {
		log.Error("Could not connect to incus socket")
		return err
	}
	log.Debug("Successfully connected to the incus daemon")


	// TODO: check if the container is a nixploit container

	// check if the container is already stopped
	if state, err := getContainerState(containerName); err != nil {
		return err
	} else if strings.Compare(state, "Stopped") == 0 {
		log.Infof("%s is already stopped, aborting", containerName)
		return nil
	}

	// Updating container's state
	// Stateful is false because of https://discuss.linuxcontainers.org/t/i-couldn-t-create-a-state-snapshot-and-the-error-message-is-as-follows/24121/12
	log.Debug("Updating container's state")	
	operation, err := server.UpdateInstanceState(containerName, api.InstanceStatePut{
		Action: "stop",
		Timeout: 10,
		Force: false,
		Stateful: false,
	}, "")
	if err != nil {
		log.Errorf("while updating container's state: %s", err)
		return err
	}

	// Waiting till the end of operation
	if err = operation.Wait(); err != nil {
		log.Errorf("while waiting top update container's state: %s", err)
		return err
	}
	log.Info("Container stopped")

	return nil
}
