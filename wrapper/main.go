package main

import (
	"flag"
	"fmt"
	"time"

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
	} else {
		log.SetLevel(log.InfoLevel)
	}
	log.SetReportCaller(true)
	log.SetTimeFormat(time.TimeOnly)

	switch *action {
	case "build":
		build(*imageName)
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
