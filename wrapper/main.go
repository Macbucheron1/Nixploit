package main

import (
	"context"
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
	startCmd := &cobra.Command{
		Use:   "start <container-name>",
		Short: "Start a nixploit container",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			containerName := args[0]
			return startAction(containerName, startImageName, startNetwork)
		},
	}
	startCmd.Flags().StringVar(&startImageName, "image", "nixploit-default", "Name for the image in incus")
	startCmd.Flags().StringVar(&startNetwork, "network", "bridge", "Network for the container: bridge|none")

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

	// TODO: check if nix & incus are available
	// TODO: check if the incus socket is available
	if err := fang.Execute(context.Background(), rootCmd); err != nil {
		os.Exit(1)
	}
}
