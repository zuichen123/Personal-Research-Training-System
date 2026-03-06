package ai

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"self-study-tool/internal/platform/observability/logx"
	"self-study-tool/internal/shared/errs"
	"self-study-tool/internal/shared/httpx"
)

const (
	streamKeepaliveInterval = 5 * time.Second
	streamQueryParam        = "stream"
)

type streamOperationResult struct {
	data any
	err  error
}

func (h *Handler) maybeStreamOperation(
	w http.ResponseWriter,
	r *http.Request,
	operation string,
	run func() (any, error),
) bool {
	if !shouldUseStream(r) {
		return false
	}
	if err := h.streamOperation(w, r, operation, run); err != nil {
		httpx.WriteError(w, err)
	}
	return true
}

func shouldUseStream(r *http.Request) bool {
	value := strings.ToLower(strings.TrimSpace(r.URL.Query().Get(streamQueryParam)))
	switch value {
	case "1", "true", "yes", "on":
		return true
	default:
		return false
	}
}

func (h *Handler) streamOperation(
	w http.ResponseWriter,
	r *http.Request,
	operation string,
	run func() (any, error),
) error {
	flusher, ok := w.(http.Flusher)
	if !ok {
		return errs.Internal("streaming is not supported")
	}

	header := w.Header()
	header.Set("Content-Type", "text/event-stream; charset=utf-8")
	header.Set("Cache-Control", "no-cache")
	header.Set("Connection", "keep-alive")
	header.Set("X-Accel-Buffering", "no")
	w.WriteHeader(http.StatusOK)
	flusher.Flush()

	started := time.Now()
	if err := writeStreamEvent(w, flusher, "start", map[string]any{
		"operation": operation,
		"message":   "ai request started",
	}); err != nil {
		return nil
	}

	resultCh := make(chan streamOperationResult, 1)
	go func() {
		data, err := run()
		resultCh <- streamOperationResult{data: data, err: err}
	}()

	ticker := time.NewTicker(streamKeepaliveInterval)
	defer ticker.Stop()

	heartbeat := 0
	for {
		select {
		case <-r.Context().Done():
			return nil
		case result := <-resultCh:
			elapsedMS := time.Since(started).Milliseconds()
			if result.err != nil {
				appErr := errs.FromError(result.err)
				_ = writeStreamEvent(w, flusher, "error", map[string]any{
					"operation":  operation,
					"elapsed_ms": elapsedMS,
					"error":      appErr,
				})
				_ = writeStreamEvent(w, flusher, "done", map[string]any{
					"operation": operation,
					"status":    "error",
				})
				logx.LoggerFromContext(r.Context()).Warn(
					"ai stream operation failed",
					"operation", operation,
					"elapsed_ms", elapsedMS,
					"error_code", appErr.Code,
					"error_message", appErr.Message,
				)
				return nil
			}
			_ = writeStreamEvent(w, flusher, "result", map[string]any{
				"operation":  operation,
				"elapsed_ms": elapsedMS,
				"data":       result.data,
			})
			_ = writeStreamEvent(w, flusher, "done", map[string]any{
				"operation": operation,
				"status":    "ok",
			})
			return nil
		case <-ticker.C:
			heartbeat++
			elapsedMS := time.Since(started).Milliseconds()
			message := fmt.Sprintf("ai request still running (%ds)", elapsedMS/1000)
			if err := writeStreamEvent(w, flusher, "progress", map[string]any{
				"operation":  operation,
				"elapsed_ms": elapsedMS,
				"heartbeat":  heartbeat,
				"message":    message,
			}); err != nil {
				return nil
			}
		}
	}
}

func writeStreamEvent(
	w http.ResponseWriter,
	flusher http.Flusher,
	event string,
	payload any,
) error {
	encoded, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	if _, err := fmt.Fprintf(w, "event: %s\n", event); err != nil {
		return err
	}
	if _, err := fmt.Fprintf(w, "data: %s\n\n", encoded); err != nil {
		return err
	}
	flusher.Flush()
	return nil
}
