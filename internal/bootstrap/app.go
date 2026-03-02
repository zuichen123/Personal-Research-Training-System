package bootstrap

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"net/http"
	"os"
	"path/filepath"

	"github.com/go-chi/chi/v5"
	"self-study-tool/internal/config"
	"self-study-tool/internal/modules/ai"
	"self-study-tool/internal/modules/mistake"
	"self-study-tool/internal/modules/practice"
	"self-study-tool/internal/modules/question"
	"self-study-tool/internal/modules/resource"
	"self-study-tool/internal/modules/system"
	"self-study-tool/internal/platform/httpserver"
	sqlitestore "self-study-tool/internal/platform/storage/sqlite"
)

type App struct {
	server *http.Server
	db     *sql.DB
}

func NewApp(cfg config.Config) (*App, error) {
	if err := ensureDatabaseDir(cfg.DatabasePath); err != nil {
		return nil, err
	}

	db, err := sqlitestore.Open(cfg.DatabasePath)
	if err != nil {
		return nil, err
	}
	if err := sqlitestore.Migrate(context.Background(), db); err != nil {
		_ = db.Close()
		return nil, err
	}

	questionRepo := question.NewSQLiteRepository(db)
	mistakeRepo := mistake.NewSQLiteRepository(db)
	practiceRepo := practice.NewSQLiteRepository(db)
	resourceRepo := resource.NewSQLiteRepository(db)

	questionService := question.NewService(questionRepo)
	mistakeService := mistake.NewService(mistakeRepo)
	resourceService := resource.NewService(resourceRepo, questionService)

	var aiClient ai.Client
	switch cfg.AIProvider {
	case "mock", "":
		aiClient = ai.NewMockClient(cfg.AIMockLatency)
	default:
		_ = db.Close()
		return nil, fmt.Errorf("unsupported ai provider: %s", cfg.AIProvider)
	}

	aiService := ai.NewService(aiClient, questionService)
	practiceService := practice.NewService(practiceRepo, questionService, aiService, mistakeService)

	questionHandler := question.NewHandler(questionService)
	mistakeHandler := mistake.NewHandler(mistakeService)
	aiHandler := ai.NewHandler(aiService)
	practiceHandler := practice.NewHandler(practiceService)
	resourceHandler := resource.NewHandler(resourceService, cfg.UploadMaxBytes)
	systemHandler := system.NewHandler()

	router := httpserver.NewRouter(cfg.WriteTimeout, func(r chi.Router) {
		r.Get("/", func(w http.ResponseWriter, _ *http.Request) {
			_, _ = w.Write([]byte("Self Study Tool API"))
		})

		r.Route("/api/v1", func(r chi.Router) {
			systemHandler.RegisterRoutes(r)
			questionHandler.RegisterRoutes(r)
			mistakeHandler.RegisterRoutes(r)
			aiHandler.RegisterRoutes(r)
			practiceHandler.RegisterRoutes(r)
			resourceHandler.RegisterRoutes(r)
		})
	})

	addr := ":" + cfg.HTTPPort
	server := httpserver.New(addr, httpserver.Config{
		ReadTimeout:  cfg.ReadTimeout,
		WriteTimeout: cfg.WriteTimeout,
	}, router)

	return &App{server: server, db: db}, nil
}

func (a *App) Run() error {
	httpserver.LogStart(a.server.Addr)
	if err := a.server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		return err
	}
	return nil
}

func (a *App) Shutdown(ctx context.Context) error {
	var joined error
	if err := a.server.Shutdown(ctx); err != nil {
		joined = err
	}
	if a.db != nil {
		if err := a.db.Close(); err != nil {
			joined = errors.Join(joined, err)
		}
	}
	return joined
}

func ensureDatabaseDir(dbPath string) error {
	dir := filepath.Dir(dbPath)
	if dir == "." || dir == "" {
		return nil
	}
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return fmt.Errorf("create database dir: %w", err)
	}
	return nil
}
