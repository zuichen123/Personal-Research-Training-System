package logx

import (
	"fmt"
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"strings"
	"sync"

	"gopkg.in/natefinch/lumberjack.v2"
)

type Config struct {
	AppEnv              string
	Level               string
	Format              string
	StdoutEnabled       bool
	FileEnabled         bool
	FilePath            string
	FileMaxSizeMB       int
	FileMaxBackups      int
	FileMaxAgeDays      int
	FileCompress        bool
	HTTPBodyEnabled     bool
	HTTPBodyMaxBytes    int
	RedactionMode       string
	LogSQLEnabled       bool
	LogSQLSlowMS        int
	LogAISummaryEnabled bool
}

var (
	mu            sync.RWMutex
	defaultLogger = slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
	defaultCfg    = Config{
		AppEnv:              "development",
		Level:               "info",
		Format:              "json",
		StdoutEnabled:       true,
		FileEnabled:         true,
		FilePath:            "./data/logs/app.log",
		FileMaxSizeMB:       20,
		FileMaxBackups:      10,
		FileMaxAgeDays:      7,
		HTTPBodyMaxBytes:    2048,
		RedactionMode:       "production_only",
		LogSQLEnabled:       true,
		LogSQLSlowMS:        200,
		LogAISummaryEnabled: true,
	}
)

func Init(cfg Config) error {
	if cfg.Level == "" {
		cfg.Level = defaultCfg.Level
	}
	if cfg.Format == "" {
		cfg.Format = defaultCfg.Format
	}
	if cfg.AppEnv == "" {
		cfg.AppEnv = defaultCfg.AppEnv
	}
	if cfg.FilePath == "" {
		cfg.FilePath = defaultCfg.FilePath
	}
	if cfg.FileMaxSizeMB <= 0 {
		cfg.FileMaxSizeMB = defaultCfg.FileMaxSizeMB
	}
	if cfg.FileMaxBackups <= 0 {
		cfg.FileMaxBackups = defaultCfg.FileMaxBackups
	}
	if cfg.FileMaxAgeDays <= 0 {
		cfg.FileMaxAgeDays = defaultCfg.FileMaxAgeDays
	}
	if cfg.HTTPBodyMaxBytes <= 0 {
		cfg.HTTPBodyMaxBytes = defaultCfg.HTTPBodyMaxBytes
	}
	if cfg.RedactionMode == "" {
		cfg.RedactionMode = defaultCfg.RedactionMode
	}
	if cfg.LogSQLSlowMS <= 0 {
		cfg.LogSQLSlowMS = defaultCfg.LogSQLSlowMS
	}

	level := parseLevel(cfg.Level)
	writer, err := buildWriter(cfg)
	if err != nil {
		return err
	}
	options := &slog.HandlerOptions{Level: level}

	var handler slog.Handler
	if strings.EqualFold(cfg.Format, "text") {
		handler = slog.NewTextHandler(writer, options)
	} else {
		handler = slog.NewJSONHandler(writer, options)
	}

	logger := slog.New(handler).With(
		slog.String("service", "self-study-api"),
		slog.String("app_env", cfg.AppEnv),
	)

	mu.Lock()
	defaultLogger = logger
	defaultCfg = cfg
	mu.Unlock()
	slog.SetDefault(logger)
	return nil
}

func L() *slog.Logger {
	mu.RLock()
	defer mu.RUnlock()
	return defaultLogger
}

func ConfigSnapshot() Config {
	mu.RLock()
	defer mu.RUnlock()
	return defaultCfg
}

func parseLevel(raw string) slog.Leveler {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case "debug":
		return slog.LevelDebug
	case "warn", "warning":
		return slog.LevelWarn
	case "error":
		return slog.LevelError
	default:
		return slog.LevelInfo
	}
}

func buildWriter(cfg Config) (io.Writer, error) {
	writers := make([]io.Writer, 0, 2)
	if cfg.StdoutEnabled {
		writers = append(writers, os.Stdout)
	}
	if cfg.FileEnabled {
		dir := filepath.Dir(cfg.FilePath)
		if dir != "" && dir != "." {
			if err := os.MkdirAll(dir, 0o755); err != nil {
				return nil, fmt.Errorf("create log dir: %w", err)
			}
		}
		writers = append(writers, &lumberjack.Logger{
			Filename:   cfg.FilePath,
			MaxSize:    cfg.FileMaxSizeMB,
			MaxBackups: cfg.FileMaxBackups,
			MaxAge:     cfg.FileMaxAgeDays,
			Compress:   cfg.FileCompress,
		})
	}
	if len(writers) == 0 {
		return io.Discard, nil
	}
	return io.MultiWriter(writers...), nil
}
