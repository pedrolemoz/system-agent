package agent

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"
)

func TestHealth(t *testing.T) {
	recorder := httptest.NewRecorder()
	NewHandler(func() error { return nil }).ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, "/health", nil))
	if recorder.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusOK)
	}
	var body map[string]string
	if err := json.NewDecoder(recorder.Body).Decode(&body); err != nil || body["status"] != "ok" {
		t.Fatalf("body = %q, error = %v", recorder.Body.String(), err)
	}
}

func TestShutdownRespondsAndTriggersOnce(t *testing.T) {
	var calls atomic.Int32
	called := make(chan struct{}, 1)
	handler := NewHandler(func() error {
		calls.Add(1)
		called <- struct{}{}
		return nil
	})

	for range 2 {
		recorder := httptest.NewRecorder()
		handler.ServeHTTP(recorder, httptest.NewRequest(http.MethodPost, "/shutdown", nil))
		if recorder.Code != http.StatusOK || recorder.Body.String() != "{\"status\":\"shutting_down\"}\n" {
			t.Fatalf("response = %d %q", recorder.Code, recorder.Body.String())
		}
	}

	select {
	case <-called:
	case <-time.After(2 * time.Second):
		t.Fatal("shutdown was not called")
	}
	if calls.Load() != 1 {
		t.Fatalf("shutdown calls = %d, want 1", calls.Load())
	}
}

func TestWrongMethods(t *testing.T) {
	for _, test := range []struct{ path, method, allow string }{
		{"/health", http.MethodPost, http.MethodGet},
		{"/shutdown", http.MethodGet, http.MethodPost},
	} {
		recorder := httptest.NewRecorder()
		NewHandler(func() error { return nil }).ServeHTTP(recorder, httptest.NewRequest(test.method, test.path, nil))
		if recorder.Code != http.StatusMethodNotAllowed || recorder.Header().Get("Allow") != test.allow {
			t.Errorf("%s %s returned %d Allow=%q", test.method, test.path, recorder.Code, recorder.Header().Get("Allow"))
		}
	}
}
