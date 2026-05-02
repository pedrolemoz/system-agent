package server

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"

	"system-agent/internal/config"
	"system-agent/internal/metrics"
	"system-agent/internal/system"
)

func Run(cfg *config.Config) error {
	mux := http.NewServeMux()
	mux.HandleFunc("/health", handleHealth)
	mux.HandleFunc("/metrics", handleMetrics)
	mux.HandleFunc("/shutdown", makeShutdownHandler(cfg))
	addr := fmt.Sprintf("%s:%d", cfg.Host, cfg.Port)
	return http.ListenAndServe(addr, mux)
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	writeJSON(w, map[string]string{"status": "ok"})
}

func handleMetrics(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	m, err := metrics.Collect()
	if err != nil {
		log.Printf("metrics error: %v", err)
		http.Error(w, "failed to collect metrics", http.StatusInternalServerError)
		return
	}
	writeJSON(w, m)
}

func makeShutdownHandler(cfg *config.Config) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		if !cfg.AllowShutdown {
			http.Error(w, "shutdown not allowed", http.StatusForbidden)
			return
		}
		writeJSON(w, map[string]string{"status": "shutting_down"})
		go func() {
			time.Sleep(500 * time.Millisecond)
			if err := system.Shutdown(); err != nil {
				log.Printf("shutdown error: %v", err)
			}
		}()
	}
}

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	enc := json.NewEncoder(w)
	enc.SetIndent("", "  ")
	if err := enc.Encode(v); err != nil {
		log.Printf("json encode: %v", err)
	}
}
