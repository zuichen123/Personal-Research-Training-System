package config

import (
	"os"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	HTTPPort            string
	ReadTimeout         time.Duration
	WriteTimeout        time.Duration
	ShutdownTimeout     time.Duration
	AIProvider          string
	AIMockLatency       time.Duration
	AIHTTPTimeout       time.Duration
	AIFallbackToMock    bool
	AIOpenAIBaseURL     string
	AIOpenAIAPIKey      string
	AIOpenAIModel       string
	AIGeminiAPIKey      string
	AIGeminiModel       string
	AIClaudeAPIKey      string
	AIClaudeModel       string
	DatabasePath        string
	UploadMaxBytes      int64
	AppEnv              string
	LogLevel            string
	LogFormat           string
	LogStdoutEnabled    bool
	LogFileEnabled      bool
	LogFilePath         string
	LogFileMaxSizeMB    int
	LogFileMaxBackups   int
	LogFileMaxAgeDays   int
	LogCompress         bool
	LogHTTPBodyEnabled  bool
	LogHTTPBodyMaxBytes int
	LogRedactionMode    string
	LogSQLEnabled       bool
	LogSQLSlowMS        int
	LogAISummaryEnabled bool
}

func Load() Config {
	return Config{
		HTTPPort:            getEnv("APP_PORT", "8080"),
		ReadTimeout:         getEnvDuration("HTTP_READ_TIMEOUT", 10*time.Second),
		WriteTimeout:        getEnvDuration("HTTP_WRITE_TIMEOUT", 15*time.Second),
		ShutdownTimeout:     getEnvDuration("HTTP_SHUTDOWN_TIMEOUT", 10*time.Second),
		AIProvider:          getEnv("AI_PROVIDER", "mock"),
		AIMockLatency:       getEnvDuration("AI_MOCK_LATENCY", 200*time.Millisecond),
		AIHTTPTimeout:       getEnvDuration("AI_HTTP_TIMEOUT", 20*time.Second),
		AIFallbackToMock:    getEnvBool("AI_FALLBACK_TO_MOCK", true),
		AIOpenAIBaseURL:     getEnv("AI_OPENAI_BASE_URL", "https://api.openai.com/v1"),
		AIOpenAIAPIKey:      getEnv("AI_OPENAI_API_KEY", ""),
		AIOpenAIModel:       getEnv("AI_OPENAI_MODEL", "gpt-4o-mini"),
		AIGeminiAPIKey:      getEnv("AI_GEMINI_API_KEY", ""),
		AIGeminiModel:       getEnv("AI_GEMINI_MODEL", "gemini-1.5-flash"),
		AIClaudeAPIKey:      getEnv("AI_CLAUDE_API_KEY", ""),
		AIClaudeModel:       getEnv("AI_CLAUDE_MODEL", "claude-3-5-sonnet-20241022"),
		DatabasePath:        getEnv("SQLITE_PATH", "./data/self-study.db"),
		UploadMaxBytes:      getEnvInt64("UPLOAD_MAX_BYTES", 20*1024*1024),
		AppEnv:              getEnv("APP_ENV", "development"),
		LogLevel:            strings.ToLower(getEnv("LOG_LEVEL", "info")),
		LogFormat:           strings.ToLower(getEnv("LOG_FORMAT", "json")),
		LogStdoutEnabled:    getEnvBool("LOG_STDOUT_ENABLED", true),
		LogFileEnabled:      getEnvBool("LOG_FILE_ENABLED", true),
		LogFilePath:         getEnv("LOG_FILE_PATH", "./data/logs/app.log"),
		LogFileMaxSizeMB:    getEnvInt("LOG_FILE_MAX_SIZE_MB", 20),
		LogFileMaxBackups:   getEnvInt("LOG_FILE_MAX_BACKUPS", 10),
		LogFileMaxAgeDays:   getEnvInt("LOG_FILE_MAX_AGE_DAYS", 7),
		LogCompress:         getEnvBool("LOG_COMPRESS", false),
		LogHTTPBodyEnabled:  getEnvBool("LOG_HTTP_BODY_ENABLED", false),
		LogHTTPBodyMaxBytes: getEnvInt("LOG_HTTP_BODY_MAX_BYTES", 2048),
		LogRedactionMode:    strings.ToLower(getEnv("LOG_REDACTION_MODE", "production_only")),
		LogSQLEnabled:       getEnvBool("LOG_SQL_ENABLED", true),
		LogSQLSlowMS:        getEnvInt("LOG_SQL_SLOW_MS", 200),
		LogAISummaryEnabled: getEnvBool("LOG_AI_SUMMARY_ENABLED", true),
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

func getEnvBool(key string, fallback bool) bool {
	raw, ok := os.LookupEnv(key)
	if !ok || strings.TrimSpace(raw) == "" {
		return fallback
	}
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case "1", "true", "yes", "y", "on":
		return true
	case "0", "false", "no", "n", "off":
		return false
	default:
		return fallback
	}
}

func getEnvInt(key string, fallback int) int {
	raw, ok := os.LookupEnv(key)
	if !ok || strings.TrimSpace(raw) == "" {
		return fallback
	}
	v, err := strconv.Atoi(raw)
	if err != nil || v <= 0 {
		return fallback
	}
	return v
}
