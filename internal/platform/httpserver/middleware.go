package httpserver

import (
	"bytes"
	"io"
	"log/slog"
	"net/http"
	"runtime/debug"
	"strings"
	"time"

	"github.com/go-chi/chi/v5/middleware"
	"self-study-tool/internal/platform/observability/logx"
)

type MiddlewareConfig struct {
	Timeout          time.Duration
	HTTPBodyEnabled  bool
	HTTPBodyMaxBytes int
	RedactionMode    string
	AppEnv           string
}

const defaultMaxBodyBytes int64 = 1 << 20 // 1 MB

func RequestMiddleware(cfg MiddlewareConfig) func(http.Handler) http.Handler {
	logCfg := logx.ConfigSnapshot()
	logCfg.HTTPBodyEnabled = cfg.HTTPBodyEnabled
	logCfg.HTTPBodyMaxBytes = cfg.HTTPBodyMaxBytes
	logCfg.RedactionMode = cfg.RedactionMode
	logCfg.AppEnv = cfg.AppEnv

	return func(next http.Handler) http.Handler {
		handler := middleware.Timeout(cfg.Timeout)(next)
		handler = requestLogger(logCfg)(handler)
		handler = traceMiddleware(handler)
		handler = middleware.RequestID(handler)
		handler = middleware.RealIP(handler)
		handler = securityHeaders(handler)
		handler = maxBodySize(defaultMaxBodyBytes)(handler)
		handler = recoverer(handler)
		return handler
	}
}

func securityHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		next.ServeHTTP(w, r)
	})
}

func maxBodySize(maxBytes int64) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.Body != nil {
				r.Body = http.MaxBytesReader(w, r.Body, maxBytes)
			}
			next.ServeHTTP(w, r)
		})
	}
}

func LogStart(addr string) {
	logx.L().Info("http server listening", slog.String("addr", addr))
}

func traceMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		traceID := logx.EnsureTraceIDFromRequest(r)
		w.Header().Set(logx.TraceHeader, traceID)
		ctx := logx.WithTraceID(r.Context(), traceID)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func recoverer(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if rec := recover(); rec != nil {
				logger := logx.LoggerFromContext(r.Context())
				logger.Error("panic recovered",
					slog.Any("panic", rec),
					slog.String("stack", string(debug.Stack())),
					slog.String("method", r.Method),
					slog.String("path", r.URL.Path),
				)
				http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
			}
		}()
		next.ServeHTTP(w, r)
	})
}

func requestLogger(cfg logx.Config) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()
			logger := logx.LoggerFromContext(r.Context())
			wrapped := middleware.NewWrapResponseWriter(w, r.ProtoMajor)
			preview, hasPreview := requestPreview(r, cfg)

			logger.Debug("http request started",
				slog.String("event", "http.request.start"),
				slog.String("method", r.Method),
				slog.String("path", r.URL.Path),
				slog.String("query", r.URL.RawQuery),
				slog.String("remote_ip", r.RemoteAddr),
				slog.Int64("content_length", r.ContentLength),
			)

			next.ServeHTTP(wrapped, r)

			latency := time.Since(start)
			status := wrapped.Status()
			if status == 0 {
				status = http.StatusOK
			}

			fields := []slog.Attr{
				slog.String("event", "http.request.end"),
				slog.String("method", r.Method),
				slog.String("path", r.URL.Path),
				slog.String("query", r.URL.RawQuery),
				slog.Int("status", status),
				slog.Int64("response_size", int64(wrapped.BytesWritten())),
				slog.Int64("latency_ms", latency.Milliseconds()),
				slog.String("trace_header", w.Header().Get(logx.TraceHeader)),
			}
			if hasPreview {
				fields = append(fields, slog.String("request_preview", preview))
			}

			switch {
			case status >= 500:
				logger.Error("http request completed", attrsToAny(fields)...)
			case status >= 400:
				logger.Warn("http request completed", attrsToAny(fields)...)
			default:
				logger.Info("http request completed", attrsToAny(fields)...)
			}
		})
	}
}

func attrsToAny(attrs []slog.Attr) []any {
	out := make([]any, 0, len(attrs))
	for _, attr := range attrs {
		out = append(out, attr)
	}
	return out
}

func requestPreview(r *http.Request, cfg logx.Config) (string, bool) {
	if !cfg.HTTPBodyEnabled || cfg.HTTPBodyMaxBytes <= 0 {
		return "", false
	}
	if r.Body == nil {
		return "", false
	}
	if r.ContentLength < 0 || r.ContentLength > int64(cfg.HTTPBodyMaxBytes) {
		return "", false
	}
	contentType := strings.ToLower(r.Header.Get("Content-Type"))
	if !(strings.Contains(contentType, "application/json") || strings.Contains(contentType, "text/")) {
		return "", false
	}
	raw, err := io.ReadAll(io.LimitReader(r.Body, int64(cfg.HTTPBodyMaxBytes)))
	if err != nil {
		return "", false
	}
	r.Body = io.NopCloser(bytes.NewBuffer(raw))
	preview := string(raw)
	if logx.ShouldRedactBody(cfg) {
		preview = logx.RedactString(preview)
	}
	return preview, true
}
