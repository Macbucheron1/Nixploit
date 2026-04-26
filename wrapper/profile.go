package main

import (
	"strings"

	"github.com/charmbracelet/log"
	"github.com/lxc/incus/v6/shared/api"
)

// Check if a profile alreay exist
func thisProfileExist (profileName string) (bool, error) {
	// connect to the incus server
	log.Debug("Try to connect to the incus daemon")
	server, err := getIncusServer()
	if err != nil {
		log.Error("Could not connect to incus socket")
		return false, err
	}
	log.Debug("Successfully connected to the incus daemon")

	log.Debugf("Fetching %s's profile", profileName)
	profile, _, err := server.GetProfile(profileName)
	if profile == nil && strings.Contains(err.Error(), "Profile not found") {
		log.Debugf("Profile %s not found", profileName)
		return false, nil
	} else if profile == nil {
		log.Errorf("While fetching profile %s: %s", profileName, err)
		return false, err
	}
	
	return true, nil
}

// Wrapper around incus function CreateProfile
func createProfile (name string, config api.ProfilePut) error {
	// connect to the incus server
	log.Debug("Try to connect to the incus daemon")
	server, err := getIncusServer()
	if err != nil {
		log.Error("Could not connect to incus socket")
		return err
	}
	log.Debug("Successfully connected to the incus daemon")

	// Create the profile
	log.Debugf("Creating %s profile", name)
	err = server.CreateProfile(api.ProfilesPost{
		Name: name,
		ProfilePut: config,
	});
	if err != nil {
		log.Errorf("While creating %s profile: %s", name, err)
		return err
	}
	log.Debugf("%s profile created", name)

	return nil
}

func applyProfiles(containerName string, profiles []string) error {
	// connect to the incus server
	log.Debug("Try to connect to the incus daemon")
	server, err := getIncusServer()
	if err != nil {
		log.Error("Could not connect to incus socket")
		return err
	}
	log.Debug("Successfully connected to the incus daemon")

	// Get to instance variable to prevent from overwrite
	log.Debug("Get current instance variable")
	instance, etag, err := server.GetInstance(containerName)
	if err != nil {
		log.Errorf("While getting instance: %s", err)
		return err
	}
	config := instance.Writable()

	// Update the instance with the profiles
	log.Debugf("Updating %s with those profiles: %s", containerName, profiles)
	config.Profiles = profiles
	operation, err := server.UpdateInstance(containerName, config, etag)
	if err != nil {
		log.Errorf("While updating instance: %s", err)
		return err
	}
	if err := operation.Wait(); err != nil {
		log.Errorf("While waiting to update instance: %s", err)
		return err
	}

	return nil
}

// Create the network nixploit-net-bridge
func createNetworkBridge() error {
	// connect to the incus server
	log.Debug("Try to connect to the incus daemon")
	server, err := getIncusServer()
	if err != nil {
		log.Error("Could not connect to incus socket")
		return err
	}
	log.Debug("Successfully connected to the incus daemon")

	// Check if the network already exist
	log.Debug("Checking if nixploit-net-bridge network exist")
	if network, _, err := server.GetNetwork("nixploit-net-b"); network != nil {
		log.Debug("nixploit-net-bridge network already exist, skipping")
		return nil
	} else if !strings.Contains(err.Error(), "Network not found"){
		log.Errorf("While getting network info: %s", err)
		return err
	}

	// Create the network
	log.Debug("Creating the nixploit-net-bridge network")
	err = server.CreateNetwork(api.NetworksPost{
		Name: "nixploit-net-b",
		Type: "bridge",
		NetworkPut: api.NetworkPut{
			Config: api.ConfigMap{
				"ipv4.address": "auto",
				"ipv4.nat": "true",
				"ipv6.address": "none",
			},
			Description: "Bridge network for nixploit",
		},
	})
	if err != nil {
		log.Errorf("While creating network: %s", err)
		return err
	}

	return nil
}

// Create the profile nixploit-net-bridge
func createNetworkBridgeProfile() error {
	// Check to see if the profile already exist
	if result, err := thisProfileExist("nixploit-net-bridge"); err != nil{
		return err
	} else if result {
		log.Debug("nixploit-net-bridge profile already exist, skipping")
		return nil
	}

	// Create the configuration
	config := api.ProfilePut{
		Config: api.ConfigMap{},
		Description: "",
		Devices: api.DevicesMap{
			"eth0": {
				"type":    "nic",
				"name":    "eth0",
				"network": "nixploit-net-b",
			},
		},
	}

	// Actually creating the profil
	if err := createProfile("nixploit-net-bridge", config); err != nil {
		return err
	}
	return nil
}

func createStorageBtrfs (){


}

func createGuiProfile () {
}

func createGpuProfile () {
}
