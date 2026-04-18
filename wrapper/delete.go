package main

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/log"
)

func deleteAction(containerName string) error {
	log.Infof("Deleting %s container", containerName)

	// Connect to the incus daemon
	log.Debug("Try to connect to the incus daemon")
	server, err := getIncusServer()
	if err != nil {
		log.Error("Could not connect to incus socket")
		return err
	}
	log.Debug("Successfully connected to the incus daemon")

	// Check if the instance is running
	// If so ask the user to stop it
	if state, err := getContainerState(containerName); err != nil {
		return err
	} else if strings.Compare(state, "Running") == 0 {
		log.Debug("Container is running")
		// TODO: add a --force to bypass asYesNo
		if isYes, err := askYesNo("The container is still running, do you want to stop it ?"); err != nil {
		} else if isYes {
			if err := stopAction(containerName); err != nil {
				log.Errorf("Could not stop the container before destroying it")
				return err
			}
		} else {
			return fmt.Errorf("Cannot destroy a running container")
		}
	}

	// Delete the container
	log.Debug("Deleting the container")
	operation, err := server.DeleteInstance(containerName)
	if err != nil {
		log.Errorf("While deleting %s: %s", containerName, err)
		return err
	}

	// Wait for the operation to succeed
	if err := operation.Wait(); err != nil {
		log.Errorf("While waiting to delete container: %s", err)
		return err
	}

	log.Infof("Successfully deleted %s container", containerName)
	return nil
}
