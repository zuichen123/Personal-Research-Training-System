package logx

import (
	"context"
	"log/slog"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5/middleware"
	"github.com/google/uuid"
)

const TraceHeader = "X-Trace-ID"

type contextKey string

const traceIDKey contextKey = "trace_id"

func NewTraceID() string {
	return uuid.NewString()
}

func WithTraceID(ctx context.Context, traceID string) context.Context {
	return context.WithValue(ctx, traceIDKey, strings.TrimSpace(traceID))
}

func TraceIDFromContext(ctx context.Context) string {
	v, _ := ctx.Value(traceIDKey).(string)
	return strings.TrimSpace(v)
}

func LoggerFromContext(ctx context.Context) *slog.Logger {
	traceID := TraceIDFromContext(ctx)
	requestID := middleware.GetReqID(ctx)
	logger := L()
	if traceID != "" {
		logger = logger.With(slog.String("trace_id", traceID))
	}
	if requestID != "" {
		logger = logger.With(slog.String("request_id", requestID))
	}
	return logger
}

func EnsureTraceIDFromRequest(r *http.Request) string {
	traceID := strings.TrimSpace(r.Header.Get(TraceHeader))
	if traceID == "" {
		traceID = NewTraceID()
	}
	return traceID
}
