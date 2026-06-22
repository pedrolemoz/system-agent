package main

import (
	"context"
	"errors"
	"flag"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/pedrolemoz/systemagent/internal/agent"
	"github.com/pedrolemoz/systemagent/internal/power"
)

var (
	version   = "dev"
	buildTime = "unknown"
)

func main() {
	address := flag.String("listen", ":8732", "address on which to listen")
	flag.Parse()

	handler := agent.NewHandler(power.Shutdown)
	server := &http.Server{
		Addr:              *address,
		Handler:           handler,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      10 * time.Second,
		IdleTimeout:       30 * time.Second,
	}

	stopped := make(chan os.Signal, 1)
	signal.Notify(stopped, os.Interrupt, syscall.SIGTERM)
	go func() {
		<-stopped
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := server.Shutdown(ctx); err != nil {
			log.Printf("graceful shutdown failed: %v", err)
		}
	}()

	log.Printf("SystemAgent %s (%s) listening on %s", version, buildTime, *address)
	if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatal(err)
	}
}
