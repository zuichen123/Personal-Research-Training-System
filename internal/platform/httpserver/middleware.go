package httpserver

import (
	"log"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5/middleware"
)

func RequestMiddleware(timeout time.Duration) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return middleware.Timeout(timeout)(
			middleware.RealIP(
				middleware.RequestID(
					middleware.Recoverer(
						middleware.Logger(next),
					),
				),
			),
		)
	}
}

func LogStart(addr string) {
	log.Printf("http server listening on %s", addr)
}
