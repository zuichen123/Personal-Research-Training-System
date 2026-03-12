package httpserver

import (
	"bufio"
	"context"
	"net"
	"net/http"
	"sync"
	"time"
)

type activityTimeoutWriteCloser interface {
	http.ResponseWriter
	Close()
}

type activityTimeoutCore struct {
	http.ResponseWriter
	controller *http.ResponseController
	timeout    time.Duration
	cancel     context.CancelCauseFunc

	mu       sync.Mutex
	timer    *time.Timer
	closed   bool
	timedOut bool
}

func newActivityTimeoutWriter(
	w http.ResponseWriter,
	protoMajor int,
	timeout time.Duration,
	cancel context.CancelCauseFunc,
) activityTimeoutWriteCloser {
	core := &activityTimeoutCore{
		ResponseWriter: w,
		controller:     http.NewResponseController(w),
		timeout:        timeout,
		cancel:         cancel,
	}

	core.timer = time.AfterFunc(timeout, func() {
		core.mu.Lock()
		if core.closed || core.timedOut {
			core.mu.Unlock()
			return
		}
		core.timedOut = true
		core.mu.Unlock()

		cancel(context.DeadlineExceeded)
		_ = core.controller.SetWriteDeadline(time.Now())
	})

	_ = core.controller.SetWriteDeadline(time.Now().Add(timeout))

	_, fl := w.(http.Flusher)
	if protoMajor == 2 {
		_, ps := w.(http.Pusher)
		if fl && ps {
			return &activityTimeoutHTTP2Writer{activityTimeoutCore: core}
		}
	} else {
		_, hj := w.(http.Hijacker)
		if fl && hj {
			return &activityTimeoutFlushHijackWriter{activityTimeoutCore: core}
		}
		if hj {
			return &activityTimeoutHijackWriter{activityTimeoutCore: core}
		}
	}

	if fl {
		return &activityTimeoutFlushWriter{activityTimeoutCore: core}
	}
	return core
}

func (w *activityTimeoutCore) Close() {
	w.mu.Lock()
	if w.closed {
		w.mu.Unlock()
		return
	}
	w.closed = true
	timer := w.timer
	w.mu.Unlock()

	if timer != nil {
		timer.Stop()
	}
}

func (w *activityTimeoutCore) touch() {
	_ = w.controller.SetWriteDeadline(time.Now().Add(w.timeout))

	w.mu.Lock()
	if w.closed || w.timedOut {
		w.mu.Unlock()
		return
	}
	if w.timer != nil {
		w.timer.Reset(w.timeout)
	}
	w.mu.Unlock()
}

func (w *activityTimeoutCore) WriteHeader(statusCode int) {
	w.touch()
	w.ResponseWriter.WriteHeader(statusCode)
}

func (w *activityTimeoutCore) Write(buf []byte) (int, error) {
	w.touch()
	return w.ResponseWriter.Write(buf)
}

func (w *activityTimeoutCore) Unwrap() http.ResponseWriter {
	if unwrapper, ok := w.ResponseWriter.(interface{ Unwrap() http.ResponseWriter }); ok {
		return unwrapper.Unwrap()
	}
	return w.ResponseWriter
}

type activityTimeoutFlushWriter struct {
	*activityTimeoutCore
}

func (w *activityTimeoutFlushWriter) Flush() {
	w.touch()
	w.ResponseWriter.(http.Flusher).Flush()
}

type activityTimeoutHijackWriter struct {
	*activityTimeoutCore
}

func (w *activityTimeoutHijackWriter) Hijack() (net.Conn, *bufio.ReadWriter, error) {
	w.touch()
	return w.ResponseWriter.(http.Hijacker).Hijack()
}

type activityTimeoutFlushHijackWriter struct {
	*activityTimeoutCore
}

func (w *activityTimeoutFlushHijackWriter) Flush() {
	w.touch()
	w.ResponseWriter.(http.Flusher).Flush()
}

func (w *activityTimeoutFlushHijackWriter) Hijack() (net.Conn, *bufio.ReadWriter, error) {
	w.touch()
	return w.ResponseWriter.(http.Hijacker).Hijack()
}

type activityTimeoutHTTP2Writer struct {
	*activityTimeoutCore
}

func (w *activityTimeoutHTTP2Writer) Flush() {
	w.touch()
	w.ResponseWriter.(http.Flusher).Flush()
}

func (w *activityTimeoutHTTP2Writer) Push(target string, opts *http.PushOptions) error {
	w.touch()
	return w.ResponseWriter.(http.Pusher).Push(target, opts)
}
