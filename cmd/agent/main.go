package main

import (
	"fmt"
	"log"

	"system-agent/internal/config"
	"system-agent/internal/metrics"
	"system-agent/internal/server"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("config: %v", err)
	}
	metrics.StartPoller()
	fmt.Printf("system-agent listening on %s:%d\n", cfg.Host, cfg.Port)
	if err := server.Run(cfg); err != nil {
		log.Fatalf("server: %v", err)
	}
}
