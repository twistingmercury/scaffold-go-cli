package main

import (
	"go/basic/scaffold/internal/config"
	"log"
)

func main() {
	appConf, err := config.Load()
	if err != nil {
		log.Fatalf("could not load configuration: %s", err)
	}

	_ = appConf

	println("This is an empty Go project. Replace this with your app.")
}
