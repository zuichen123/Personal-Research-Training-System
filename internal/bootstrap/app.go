package bootstrap

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"self-study-tool/internal/config"
	"self-study-tool/internal/modules/ai"
	"self-study-tool/internal/modules/mistake"
	"self-study-tool/internal/modules/plan"
	"self-study-tool/internal/modules/pomodoro"
	"self-study-tool/internal/modules/practice"
	"self-study-tool/internal/modules/profile"
	"self-study-tool/internal/modules/question"
	"self-study-tool/internal/modules/resource"
	"self-study-tool/internal/modules/system"
	"self-study-tool/internal/platform/httpserver"
	"self-study-tool/internal/platform/observability/logx"
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
	planRepo := plan.NewSQLiteRepository(db)
	pomodoroRepo := pomodoro.NewSQLiteRepository(db)
	practiceRepo := practice.NewSQLiteRepository(db)
	resourceRepo := resource.NewSQLiteRepository(db)
	profileRepo := profile.NewSQLiteRepository(db)

	questionService := question.NewService(questionRepo)
	mistakeService := mistake.NewService(mistakeRepo)
	planService := plan.NewService(planRepo)
	pomodoroService := pomodoro.NewService(pomodoroRepo)
	resourceService := resource.NewService(resourceRepo, questionService)
	profileService := profile.NewService(profileRepo)
	aiConfigRepo := ai.NewSQLiteProviderConfigRepository(db)
	aiAgentRepo := ai.NewSQLiteAgentRepository(db)

	aiRuntime := runtimeConfigFromConfig(cfg)
	dbAIConfig, hasDBAIConfig, err := aiConfigRepo.LoadProviderConfig(context.Background())
	if err != nil {
		_ = db.Close()
		return nil, err
	}
	aiRuntime = mergeRuntimeConfig(aiRuntime, cfg, dbAIConfig, hasDBAIConfig)

	aiClient, fallbackUsed, err := buildAIClient(aiRuntime)
	if err != nil {
		_ = db.Close()
		return nil, err
	}

	aiService := ai.NewServiceWithStoreAndDeps(
		aiClient,
		questionService,
		planService,
		fallbackUsed,
		aiRuntime,
		aiConfigRepo,
		aiAgentRepo,
	)
	if err := aiService.LoadPromptTemplates(context.Background()); err != nil {
		_ = db.Close()
		return nil, err
	}
	practiceService := practice.NewService(practiceRepo, questionService, aiService, mistakeService)
	aiService.SetAppControl(newAIAppControl(
		aiService,
		questionService,
		mistakeService,
		practiceService,
		planService,
		pomodoroService,
		resourceService,
		profileService,
	))

	questionHandler := question.NewHandler(questionService)
	mistakeHandler := mistake.NewHandler(mistakeService)
	planHandler := plan.NewHandler(planService)
	pomodoroHandler := pomodoro.NewHandler(pomodoroService)
	aiHandler := ai.NewHandler(aiService)
	practiceHandler := practice.NewHandler(practiceService)
	resourceHandler := resource.NewHandler(resourceService, cfg.UploadMaxBytes)
	profileHandler := profile.NewHandler(profileService)
	systemHandler := system.NewHandler()

	effectiveWriteTimeout := cfg.WriteTimeout
	minWriteTimeout := cfg.AIHTTPTimeout + 5*time.Second
	if effectiveWriteTimeout < minWriteTimeout {
		effectiveWriteTimeout = minWriteTimeout
		logx.L().Warn("http write timeout increased to align with ai timeout",
			slog.Int64("http_write_timeout_ms", cfg.WriteTimeout.Milliseconds()),
			slog.Int64("ai_http_timeout_ms", cfg.AIHTTPTimeout.Milliseconds()),
			slog.Int64("effective_write_timeout_ms", effectiveWriteTimeout.Milliseconds()),
		)
	}

	router := httpserver.NewRouter(httpserver.MiddlewareConfig{
		Timeout:          effectiveWriteTimeout,
		HTTPBodyEnabled:  cfg.LogHTTPBodyEnabled,
		HTTPBodyMaxBytes: cfg.LogHTTPBodyMaxBytes,
		RedactionMode:    cfg.LogRedactionMode,
		AppEnv:           cfg.AppEnv,
	}, func(r chi.Router) {
		r.Get("/", func(w http.ResponseWriter, _ *http.Request) {
			_, _ = w.Write([]byte("Self Study Tool API"))
		})

		r.Route("/api/v1", func(r chi.Router) {
			systemHandler.RegisterRoutes(r)
			questionHandler.RegisterRoutes(r)
			mistakeHandler.RegisterRoutes(r)
			planHandler.RegisterRoutes(r)
			pomodoroHandler.RegisterRoutes(r)
			aiHandler.RegisterRoutes(r)
			practiceHandler.RegisterRoutes(r)
			resourceHandler.RegisterRoutes(r)
			profileHandler.RegisterRoutes(r)
		})
	})

	addr := ":" + cfg.HTTPPort
	server := httpserver.New(addr, httpserver.Config{
		ReadTimeout:  cfg.ReadTimeout,
		WriteTimeout: effectiveWriteTimeout,
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

func runtimeConfigFromConfig(cfg config.Config) ai.RuntimeConfig {
	return ai.RuntimeConfig{
		Provider:       cfg.AIProvider,
		FallbackToMock: cfg.AIFallbackToMock,
		MockLatency:    cfg.AIMockLatency,
		AIHTTPTimeout:  cfg.AIHTTPTimeout,
		OpenAIBaseURL:  cfg.AIOpenAIBaseURL,
		OpenAIAPIKey:   cfg.AIOpenAIAPIKey,
		OpenAIModel:    cfg.AIOpenAIModel,
		GeminiAPIKey:   cfg.AIGeminiAPIKey,
		GeminiModel:    cfg.AIGeminiModel,
		ClaudeAPIKey:   cfg.AIClaudeAPIKey,
		ClaudeModel:    cfg.AIClaudeModel,
	}
}

func mergeRuntimeConfig(
	runtime ai.RuntimeConfig,
	cfg config.Config,
	dbCfg ai.ProviderConfigRecord,
	hasDB bool,
) ai.RuntimeConfig {
	if !hasDB {
		return runtime
	}
	if !cfg.AIProviderSet && strings.TrimSpace(dbCfg.Provider) != "" {
		runtime.Provider = dbCfg.Provider
	}
	if !cfg.AIOpenAIBaseURLSet && strings.TrimSpace(dbCfg.OpenAIBaseURL) != "" {
		runtime.OpenAIBaseURL = dbCfg.OpenAIBaseURL
	}
	if !cfg.AIOpenAIAPIKeySet && strings.TrimSpace(dbCfg.OpenAIAPIKey) != "" {
		runtime.OpenAIAPIKey = dbCfg.OpenAIAPIKey
	}
	if !cfg.AIOpenAIModelSet && strings.TrimSpace(dbCfg.OpenAIModel) != "" {
		runtime.OpenAIModel = dbCfg.OpenAIModel
	}
	if !cfg.AIGeminiAPIKeySet && strings.TrimSpace(dbCfg.GeminiAPIKey) != "" {
		runtime.GeminiAPIKey = dbCfg.GeminiAPIKey
	}
	if !cfg.AIGeminiModelSet && strings.TrimSpace(dbCfg.GeminiModel) != "" {
		runtime.GeminiModel = dbCfg.GeminiModel
	}
	if !cfg.AIClaudeAPIKeySet && strings.TrimSpace(dbCfg.ClaudeAPIKey) != "" {
		runtime.ClaudeAPIKey = dbCfg.ClaudeAPIKey
	}
	if !cfg.AIClaudeModelSet && strings.TrimSpace(dbCfg.ClaudeModel) != "" {
		runtime.ClaudeModel = dbCfg.ClaudeModel
	}
	return runtime
}

func buildAIClient(runtime ai.RuntimeConfig) (ai.Client, bool, error) {
	provider := strings.ToLower(strings.TrimSpace(runtime.Provider))
	fallbackToMock := runtime.FallbackToMock

	switch provider {
	case "", "mock":
		return ai.NewMockClient(runtime.MockLatency), false, nil
	case "openai":
		client := ai.NewOpenAIClient(ai.OpenAIConfig{
			BaseURL: runtime.OpenAIBaseURL,
			APIKey:  runtime.OpenAIAPIKey,
			Model:   runtime.OpenAIModel,
			Timeout: runtime.AIHTTPTimeout,
		})
		if client.IsReady() {
			return client, false, nil
		}
	case "gemini":
		client := ai.NewGeminiClient(ai.GeminiConfig{
			APIKey:  runtime.GeminiAPIKey,
			Model:   runtime.GeminiModel,
			Timeout: runtime.AIHTTPTimeout,
		})
		if client.IsReady() {
			return client, false, nil
		}
	case "claude":
		client := ai.NewClaudeClient(ai.ClaudeConfig{
			APIKey:  runtime.ClaudeAPIKey,
			Model:   runtime.ClaudeModel,
			Timeout: runtime.AIHTTPTimeout,
		})
		if client.IsReady() {
			return client, false, nil
		}
	default:
		return nil, false, fmt.Errorf("unsupported ai provider: %s", runtime.Provider)
	}

	if fallbackToMock {
		logx.L().Warn("ai provider is not ready, fallback to mock",
			slog.String("ai_provider", provider),
		)
		return ai.NewMockClient(runtime.MockLatency), true, nil
	}
	return nil, false, fmt.Errorf("ai provider %q is not ready, check credentials/model", provider)
}
