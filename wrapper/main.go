package main

import (
	"flag"
	"fmt"
	"time"
	"os"

	"github.com/charmbracelet/log"
)

func main() {
	action := flag.String("action", "", "build | start | info | stop | delete")
	debug := flag.Bool("debug", false, "More verbose output")
	imageName := flag.String("image-name", "nixploit", "Name for the image in incus")
	containerName := flag.String("container-name", "", "Name for the container in incus")

	flag.Parse()

	if *debug {
		log.SetLevel(log.DebugLevel)
		log.SetTimeFormat(time.TimeOnly)
		log.SetReportCaller(true)
	} else {
		log.SetLevel(log.InfoLevel)
		log.SetReportTimestamp(false)
	}

	switch *action {
	case "build":
		if err := buildAction(*imageName); err != nil {
			fmt.Printf("An error occured while building: %s\n", err)
			os.Exit(1)
		}
	case "start":
		if err := startAction(*containerName); err != nil {
			fmt.Printf("An error occured while starting: %s\n", err)
			os.Exit(1)
		}
	case "info":
		if err := infoAction(); err != nil {
			fmt.Printf("An error occured while getting information: %s\n", err)
			os.Exit(1)
		}
	case "stop":
		if err := stopAction(); err != nil {
			fmt.Printf("An error occured while stopping: %s\n", err)
			os.Exit(1)
		}
	case "delete":
		if err := deleteAction(); err != nil {
			fmt.Printf("An error occured while deleting: %s\n", err)
			os.Exit(1)
		}
	default:
		fmt.Println("wrong choice")
	}
}
