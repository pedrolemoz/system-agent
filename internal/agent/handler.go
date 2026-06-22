package agent

import (
	"encoding/json"
	"log"
	"net/http"
	"sync/atomic"
	"time"
)

type shutdownFunc func() error

type Handler struct {
	shutdown shutdownFunc
	started  atomic.Bool
}

func NewHandler(shutdown shutdownFunc) http.Handler {
	h := &Handler{shutdown: shutdown}
	mux := http.NewServeMux()
	mux.HandleFunc("/health", h.health)
	mux.HandleFunc("/shutdown", h.requestShutdown)
	return mux
}

func (h *Handler) health(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		w.Header().Set("Allow", http.MethodGet)
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (h *Handler) requestShutdown(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.Header().Set("Allow", http.MethodPost)
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "shutting_down"})
	if flusher, ok := w.(http.Flusher); ok {
		flusher.Flush()
	}

	if h.started.CompareAndSwap(false, true) {
		go func() {
			time.Sleep(500 * time.Millisecond)
			if err := h.shutdown(); err != nil {
				log.Printf("failed to shut down computer: %v", err)
				h.started.Store(false)
			}
		}()
	}
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(value); err != nil {
		log.Printf("failed to write response: %v", err)
	}
}
