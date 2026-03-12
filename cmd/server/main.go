package main

import (
	"context"
	"log/slog"
	"os"
	"os/signal"
	"syscall"

	"prts/internal/bootstrap"
	"prts/internal/config"
	"prts/internal/platform/observability/logx"
)

func main() {
	cfg := config.Load()
	if err := logx.Init(logx.Config{
		AppEnv:              cfg.AppEnv,
		Level:               cfg.LogLevel,
		Format:              cfg.LogFormat,
		StdoutEnabled:       cfg.LogStdoutEnabled,
		FileEnabled:         cfg.LogFileEnabled,
		FilePath:            cfg.LogFilePath,
		FileMaxSizeMB:       cfg.LogFileMaxSizeMB,
		FileMaxBackups:      cfg.LogFileMaxBackups,
		FileMaxAgeDays:      cfg.LogFileMaxAgeDays,
		FileCompress:        cfg.LogCompress,
		HTTPBodyEnabled:     cfg.LogHTTPBodyEnabled,
		HTTPBodyMaxBytes:    cfg.LogHTTPBodyMaxBytes,
		RedactionMode:       cfg.LogRedactionMode,
		LogSQLEnabled:       cfg.LogSQLEnabled,
		LogSQLSlowMS:        cfg.LogSQLSlowMS,
		LogAISummaryEnabled: cfg.LogAISummaryEnabled,
	}); err != nil {
		slog.Error("init logger failed", slog.String("error", err.Error()))
		os.Exit(1)
	}
	slog.Info("application starting",
		slog.String("event", "app.start"),
		slog.String("http_port", cfg.HTTPPort),
		slog.String("ai_provider", cfg.AIProvider),
		slog.String("sqlite_path", cfg.DatabasePath),
	)

	app, err := bootstrap.NewApp(cfg)
	if err != nil {
		slog.Error("bootstrap app failed", slog.String("error", err.Error()))
		os.Exit(1)
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	errCh := make(chan error, 1)
	go func() {
		errCh <- app.Run()
	}()

	select {
	case <-ctx.Done():
		slog.Info("shutdown signal received", slog.String("event", "app.shutdown.signal"))
	case err := <-errCh:
		if err != nil {
			slog.Error("server error", slog.String("error", err.Error()))
			os.Exit(1)
		}
	}

	shutdownCtx, cancel := context.WithTimeout(context.Background(), cfg.ShutdownTimeout)
	defer cancel()

	if err := app.Shutdown(shutdownCtx); err != nil {
		slog.Error("graceful shutdown failed", slog.String("error", err.Error()))
		os.Exit(1)
	}
	slog.Info("application stopped", slog.String("event", "app.shutdown.complete"))
}
