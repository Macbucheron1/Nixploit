package main

import (
	"context"
	"fmt"
	"os"
	"time"

	"charm.land/fang/v2"
	"github.com/charmbracelet/log"
	"github.com/spf13/cobra"
)

func main() {
	var debug bool

	rootCmd := &cobra.Command{
		Use:   "nixploit-default",
		Short: "Build and manage nixploit image through incus",
		PersistentPreRun: func(cmd *cobra.Command, args []string) {
			if debug {
				log.SetLevel(log.DebugLevel)
				log.SetTimeFormat(time.TimeOnly)
				log.SetReportTimestamp(true)
				log.SetReportCaller(true)
			} else {
				log.SetLevel(log.InfoLevel)
				log.SetReportTimestamp(false)
				log.SetReportCaller(false)
			}
			log.Debug("Checking if the nixploit dir exist")
			if dir, err := nixploitDir(); err != nil {
				log.Errorf("While getting nixploit dir: %s", err)
				os.Exit(1)
			} else if exist, err := nixploitDirExists(); err != nil {
				log.Errorf("While checking nixploit dir: %s", err)
				os.Exit(1)
			} else if !exist {
				log.Error("It appear that you do not have a nixploit directory !")
				log.Info("This is mandantory to build the image and to use gui features")
				if resp, err := askYesNo(fmt.Sprintf("Create the nixploit directory at %s ?", dir)); err != nil || !resp {
					os.Exit(1)
				}
				if err := createNixploitDir(); err != nil {
					os.Exit(1)
				}
			} else if err := createNixploitDir(); err != nil {
				os.Exit(1)
			}

			log.Debug("Checking if the nixploit repository is cloned")
			if exist, err := nixploitRepoExists(); err != nil {
				log.Errorf("While checking nixploit repository: %s", err)
				os.Exit(1)
			} else if !exist {
				log.Info("Nixploit also require to clone it's repository in it's directory")
				if resp, err := askYesNo("Clone https://github.com/Macbucheron1/Nixploit in the nixploit dir ?"); err != nil || !resp {
					os.Exit(1)
				}
				if err := cloneNixploitRepo(); err != nil {
					os.Exit(1)
				}
			}
		},
		RunE: func(cmd *cobra.Command, args []string) error {
			return cmd.Help()
		},
	}

	rootCmd.PersistentFlags().BoolVar(&debug, "debug", false, "More verbose output")

	var buildImageName string
	buildCmd := &cobra.Command{
		Use:   "build",
		Short: "Build and import a nixploit image",
		RunE: func(cmd *cobra.Command, args []string) error {
			return buildAction(buildImageName)
		},
	}
	buildCmd.Flags().StringVar(&buildImageName, "image", "nixploit-default", "Name for the image in incus")

	var startImageName string
	var startNetwork string
	var startNoGui bool
	startCmd := &cobra.Command{
		Use:   "start <container-name>",
		Short: "Start a nixploit container",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			containerName := args[0]
			return startAction(containerName, startImageName, startNetwork, startNoGui)
		},
	}
	startCmd.Flags().StringVar(&startImageName, "image", "nixploit-default", "Name for the image in incus")
	startCmd.Flags().StringVar(&startNetwork, "network", "bridge", "Network for the container: bridge|none")
	startCmd.Flags().BoolVar(&startNoGui, "no-gui", false,"Disable xpra, you will not be able to launch your gui apps")

	infoCmd := &cobra.Command{
		Use:   "info",
		Short: "Show current nixploit status",
		RunE: func(cmd *cobra.Command, args []string) error {
			return infoAction()
		},
	}

	stopCmd := &cobra.Command{
		Use:   "stop <container-name>",
		Short: "Stop nixploit instance",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			containerName := args[0]
			return stopAction(containerName)
		},
	}

	deleteCmd := &cobra.Command{
		Use:   "delete <container-name>",
		Short: "Delete nixploit instance",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			containerName := args[0]
			return deleteAction(containerName)
		},
	}

	rootCmd.AddCommand(
		buildCmd,
		startCmd,
		infoCmd,
		stopCmd,
		deleteCmd,
	)

	// TODO: check if the incus socket is available
	if err := fang.Execute(context.Background(), rootCmd); err != nil {
		os.Exit(1)
	}
}
