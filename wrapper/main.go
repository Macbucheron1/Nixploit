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
		Use:   "nixploit",
		Short: "Build and manage nixploit image through incus",
		PersistentPreRun: func(cmd *cobra.Command, args []string) {
			if debug {
				log.SetLevel(log.DebugLevel)
				log.SetTimeFormat(time.TimeOnly)
				log.SetReportTimestamp(false)
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

	var imageName string
	buildCmd := &cobra.Command{
		Use:   "build",
		Short: "Build and import a nixploit image",
		RunE: func(cmd *cobra.Command, args []string) error {
			return buildAction(imageName)
		},
	}
	buildCmd.Flags().StringVar(&imageName, "image-name", "nixploit", "Name for the image in incus")

	var containerName string
	startCmd := &cobra.Command{
		Use:   "start",
		Short: "Start a nixploit container",
		RunE: func(cmd *cobra.Command, args []string) error {
			return startAction(containerName)
		},
	}
	startCmd.Flags().StringVar(&containerName, "container-name", "", "Name for the container in incus")
	_ = startCmd.MarkFlagRequired("container-name")

	infoCmd := &cobra.Command{
		Use:   "info",
		Short: "Show current nixploit status",
		RunE: func(cmd *cobra.Command, args []string) error {
			return infoAction()
		},
	}

	stopCmd := &cobra.Command{
		Use:   "stop",
		Short: "Stop nixploit instance",
		RunE: func(cmd *cobra.Command, args []string) error {
			return stopAction()
		},
	}

	deleteCmd := &cobra.Command{
		Use:   "delete",
		Short: "Delete nixploit instance",
		RunE: func(cmd *cobra.Command, args []string) error {
			return deleteAction()
		},
	}

	rootCmd.AddCommand(
		buildCmd,
		startCmd,
		infoCmd,
		stopCmd,
		deleteCmd,
	)

	if err := fang.Execute(context.Background(), rootCmd); err != nil {
		os.Exit(1)
	}
}
