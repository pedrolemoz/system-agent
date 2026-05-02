package metrics

import (
	"sync/atomic"
	"time"
)

var cached atomic.Pointer[Metrics]

// StartPoller launches a background goroutine that refreshes metrics every 2 seconds.
// First collection runs immediately so cache is warm before the first HTTP request.
func StartPoller() {
	go func() {
		if m, err := collect(); err == nil {
			cached.Store(m)
		}
		ticker := time.NewTicker(2 * time.Second)
		defer ticker.Stop()
		for range ticker.C {
			if m, err := collect(); err == nil {
				cached.Store(m)
			}
		}
	}()
}

// Collect returns cached metrics (instant). Falls back to live collection only if
// the poller has not completed its first run yet.
func Collect() (*Metrics, error) {
	if m := cached.Load(); m != nil {
		return m, nil
	}
	return collect()
}
