package httpserver

import (
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/cors"
)

type Config struct {
	ReadTimeout  time.Duration
	WriteTimeout time.Duration
}

func NewRouter(mwCfg MiddlewareConfig, registrars ...func(r chi.Router)) *chi.Mux {
	r := chi.NewRouter()
	r.Use(RequestMiddleware(mwCfg))
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins: []string{"*"},
		AllowedMethods: []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowedHeaders: []string{"Accept", "Authorization", "Content-Type", "X-Trace-ID"},
		ExposedHeaders: []string{"X-Trace-ID"},
	}))

	for _, registrar := range registrars {
		registrar(r)
	}
	return r
}

func New(addr string, cfg Config, handler http.Handler) *http.Server {
	return &http.Server{
		Addr:         addr,
		Handler:      handler,
		ReadTimeout:  cfg.ReadTimeout,
		WriteTimeout: cfg.WriteTimeout,
	}
}
