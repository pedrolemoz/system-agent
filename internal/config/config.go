package config

import (
	"encoding/json"
	"errors"
	"os"
)

type Config struct {
	Host          string `json:"host"`
	Port          int    `json:"port"`
	AllowShutdown bool   `json:"allow_shutdown"`
}

const configFile = "config.json"

func Load() (*Config, error) {
	data, err := os.ReadFile(configFile)
	if errors.Is(err, os.ErrNotExist) {
		return createDefault()
	}
	if err != nil {
		return nil, err
	}
	var cfg Config
	if err := json.Unmarshal(data, &cfg); err != nil {
		return nil, err
	}
	return &cfg, nil
}

func createDefault() (*Config, error) {
	cfg := &Config{
		Host:          "0.0.0.0",
		Port:          8732,
		AllowShutdown: true,
	}
	data, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		return nil, err
	}
	if err := os.WriteFile(configFile, data, 0644); err != nil {
		return nil, err
	}
	return cfg, nil
}
