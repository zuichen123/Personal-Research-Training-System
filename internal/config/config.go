package config

import (
	"os"
	"strconv"
	"time"
)

type Config struct {
	HTTPPort        string
	ReadTimeout     time.Duration
	WriteTimeout    time.Duration
	ShutdownTimeout time.Duration
	AIProvider      string
	AIMockLatency   time.Duration
	DatabasePath    string
	UploadMaxBytes  int64
}

func Load() Config {
	return Config{
		HTTPPort:        getEnv("APP_PORT", "8080"),
		ReadTimeout:     getEnvDuration("HTTP_READ_TIMEOUT", 10*time.Second),
		WriteTimeout:    getEnvDuration("HTTP_WRITE_TIMEOUT", 15*time.Second),
		ShutdownTimeout: getEnvDuration("HTTP_SHUTDOWN_TIMEOUT", 10*time.Second),
		AIProvider:      getEnv("AI_PROVIDER", "mock"),
		AIMockLatency:   getEnvDuration("AI_MOCK_LATENCY", 200*time.Millisecond),
		DatabasePath:    getEnv("SQLITE_PATH", "./data/self-study.db"),
		UploadMaxBytes:  getEnvInt64("UPLOAD_MAX_BYTES", 20*1024*1024),
	}
}

func getEnv(key, fallback string) string {
	if value, ok := os.LookupEnv(key); ok && value != "" {
		return value
	}
	return fallback
}

func getEnvDuration(key string, fallback time.Duration) time.Duration {
	raw, ok := os.LookupEnv(key)
	if !ok || raw == "" {
		return fallback
	}
	if ms, err := strconv.Atoi(raw); err == nil {
		return time.Duration(ms) * time.Millisecond
	}
	if d, err := time.ParseDuration(raw); err == nil {
		return d
	}
	return fallback
}

func getEnvInt64(key string, fallback int64) int64 {
	raw, ok := os.LookupEnv(key)
	if !ok || raw == "" {
		return fallback
	}
	v, err := strconv.ParseInt(raw, 10, 64)
	if err != nil || v <= 0 {
		return fallback
	}
	return v
}
