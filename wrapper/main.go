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
	// containerName := flag.String("container-name", "", "Name for the container in incus")

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
		err := buildAction(*imageName)
		if err != nil {
			fmt.Printf("An error occured while building: %s\n", err)
			os.Exit(1)
		}
	case "start":
		start()
	case "info":
		info()
	case "stop":
		stop()
	case "delete":
		delete()
	default:
		fmt.Println("wrong choice")
	}
}
