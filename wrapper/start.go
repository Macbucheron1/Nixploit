package main

import (
	"fmt"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/charmbracelet/log"
	"github.com/gorilla/websocket"
	"github.com/lxc/incus/v6/client"
	"github.com/lxc/incus/v6/shared/api"
	"github.com/lxc/incus/v6/shared/termios"
)

// send the size of the terminal in which this process executes to the web socket in json format
// exemple :
// {window-resize map[height:56 width:211] 0}
func sendTermSize(control *websocket.Conn) error {
	width, height, err := termios.GetSize(int(syscall.Stdout))
	if err != nil {
		return err
	}

	msg := api.InstanceExecControl{
		Command: "window-resize",
		Args: map[string]string{
			"width":  strconv.Itoa(width),
			"height": strconv.Itoa(height),
		},
	}

	return control.WriteJSON(msg)
}

// Transmit the SIGWINCH signal to incus along with the new size
func controlSocketHandler(control *websocket.Conn) {
	//Make a channel and send SIGWINCH everytime through it
	ch := make(chan os.Signal, 10)
	signal.Notify(ch, syscall.SIGWINCH)
	defer signal.Stop(ch)

	// Send the size for the first time just to be sure
	if err := sendTermSize(control); err != nil {
		log.Warnf("Could not send initial terminal size: %v", err)
	}

	// Each time a SIGWINCH signal is sent, send the new size
	for range ch {
		log.Debug("New size detected, trying to update")
		if err := sendTermSize(control); err != nil {
			log.Warnf("Could not update terminal size: %v", err)
			break
		} else {
			log.Debug("Successfully updated the size")
		}
	}

	// Close the web socket when it's over
	_ = control.WriteMessage(
		websocket.CloseMessage,
		websocket.FormatCloseMessage(websocket.CloseNormalClosure, ""),
	)
}

// Start a container.
// If the container does not exist use imageName as the image
// If the container exist and is stopped, start it
func startAction(containerName, imageName, networkChoice string, noGuiChoice, gpuChoice bool) error {
	log.Infof("Starting container named %s using %s's image", containerName, imageName)

	// Make sur everything is ok
	log.Debug("Checking if the process is in a terminal and trying to get terminal size")
	if !termios.IsTerminal(int(syscall.Stdin)) || !termios.IsTerminal(int(syscall.Stdout)) {
		log.Error("This has not been launched inside a TTY !")
		return fmt.Errorf("interactive shell requires a TTY")
	}
	width, height, err := termios.GetSize(int(syscall.Stdout))
	if err != nil {
		log.Errorf("While getting terminal size: %s", err)
	}
	log.Debugf("This is a terminal of size %d/%d", width, height)

	// Check it the required image is in incus storage
	log.Debugf("Checking if the %s image is built in incus", imageName)
	if doesImageExist, err := imageExistInIncus(imageName); err != nil {
		return err
	} else if !doesImageExist {
		log.Error("No image for that name")
		doBuild, err := askYesNo("Do you want to build the image ?")
		if err != nil {
			log.Errorf("While asking to build the image: %s", err)
			return err
		}
		if !doBuild {
			log.Info("Exiting")
			return nil
		}
		if err := buildAction(imageName); err != nil {
			return err
		}
	}

	// Connect to the incus daemon
	log.Debug("Try to connect to the incus daemon")
	server, err := getIncusServer()
	if err != nil {
		log.Error("Could not connect to incus socket")
		return err
	}
	log.Debug("Successfully connected to the incus daemon")

	var profiles []string

	log.Debug("Adding btrfs storage")
	if err := createStorageBtrfs(); err != nil {
		return err
	}
	if err := createStorageBtrfsProfile(); err != nil {
		return err
	}
	profiles = append(profiles, "nixploit-storage-btrfs")

	// Network choice
	log.Debug("Adding the network choice")
	switch networkChoice {
	case "bridge":
		log.Debug("Bridge network selected, adding profile")
		if err := createNetworkBridge(); err != nil {
			return err
		}
		if err := createNetworkBridgeProfile(); err != nil {
			return err
		}
		profiles = append(profiles, "nixploit-net-bridge")
	case "none":
		break
	default:
		log.Errorf("%s is not a network option, choose between bridge & none", networkChoice)
		return fmt.Errorf("Wrong network choice")
	}

	log.Debug("Adding GPU choice")
	if gpuChoice {
		log.Debug("Adding the gpu")
		if err := addGpu(containerName); err != nil {
			return err
		}
	}

	// TODO: fix this once using unix socket
	if !noGuiChoice && networkChoice != "bridge" {
		log.Errorf("You cannot have no network and use XPRA")
		return fmt.Errorf("You cannot have no network and use XPRA")
	}

	// Instance option
	instance := api.InstancesPost{
		Name:  containerName,
		Start: true,
		Source: api.InstanceSource{
			Type:  "image",
			Alias: imageName,
		},
		Type: "container",
		InstancePut: api.InstancePut{
			Profiles: profiles,
		},
	}

	// Create the instance
	log.Debug("Creating the instance")
	if operation, err := server.CreateInstance(instance); err != nil {
		if strings.Contains(err.Error(), "already exists") {
			log.Warn("The container already exists")

			// TODO check if the container is using an nixploit image

			// Check if the container is stopped and if so, start it
			log.Debug("Checking current container state")
			if state, err := getContainerState(containerName); err != nil {
				return err
			} else if strings.Compare(state, "Stopped") == 0 {
				log.Debugf("Container is stopped, restarting it")
				if err := setContainerState(containerName, "start"); err != nil {
					return err
				}
			}

		} else {
			log.Error(fmt.Sprintf("Error while creating the instance: %s", err))
			return err
		}
	} else {
		if err := operation.Wait(); err != nil {
			log.Error(fmt.Sprintf("While waiting to create instance %s", err))
			return err
		}
	}
	log.Info(fmt.Sprintf("Container %s successfully started !", containerName))

	log.Debug("Adding the ssh key to the container")
	if err := addSshKey(containerName); err != nil {
		return err
	}

	if !noGuiChoice {
		go xpraConnect(containerName)
	}

	// Open a shell
	execRequest := api.InstanceExecPost{
		Command:     []string{"/run/current-system/sw/bin/bash", "-il"},
		WaitForWS:   true,
		Interactive: true,
		Width:       width,
		Height:      height,
		User:        0,
		Group:       0,
		Cwd:         "/root",
		Environment: map[string]string{
			"TERM": os.Getenv("TERM"),
		},
	}

	// Setup the terminal (set to raw mode)
	if execRequest.Interactive {
		cfd := int(syscall.Stdin)
		oldttystate, err := termios.MakeRaw(cfd)
		if err != nil {
			return err
		}
		defer termios.Restore(cfd, oldttystate)
	}

	execArgs := incus.InstanceExecArgs{
		Stdin:    os.Stdin,
		Stdout:   os.Stdout,
		Stderr:   os.Stderr,
		DataDone: make(chan bool),      // just to check if data operation are over
		Control:  controlSocketHandler, // Function that will handles windows resize or signal
	}

	// Execute the shell
	log.Debug("Executing the shell")
	for i := range 10 {
		execArgs.DataDone = make(chan bool)

		operation, err := server.ExecInstance(containerName, execRequest, &execArgs)
		if err != nil {
			log.Errorf("While opening a shell in %s", containerName)
			return err
		}
		log.Debug("Shell opened successfully")

		// Is the process dead (the shell) ?
		err = operation.Wait()
		if err == nil {
			// Are all the I/O empty ? (sockets / pipes) wait if not
			<-execArgs.DataDone
			log.Debug("Shell has been closed")
			return nil
		}
		if !strings.Contains(err.Error(), "Command not found") || i == 9 {
			log.Errorf("while waiting for the end of the process: %s", err)
			return err
		}
		log.Debug("Shell not ready yet, retrying...")
		time.Sleep(time.Second)
	}
	return nil
}
