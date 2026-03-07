package question

import (
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	"self-study-tool/internal/shared/httpx"
)

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) RegisterRoutes(r chi.Router) {
	r.Route("/questions", func(r chi.Router) {
		r.Post("/", h.create)
		r.Get("/", h.list)
		r.Put("/{id}", h.update)
		r.Delete("/{id}", h.delete)
	})
}

func (h *Handler) create(w http.ResponseWriter, r *http.Request) {
	var req CreateInput
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}

	item, err := h.service.Create(r.Context(), req)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusCreated, item)
}

func (h *Handler) list(w http.ResponseWriter, r *http.Request) {
	items, err := h.service.List(r.Context())
	if err != nil {
		httpx.WriteError(w, err)
		return
	}

	subjectFilter := strings.TrimSpace(r.URL.Query().Get("subject"))
	sourceFilter := strings.TrimSpace(r.URL.Query().Get("source"))
	if subjectFilter == "" && sourceFilter == "" {
		httpx.WriteJSON(w, http.StatusOK, items)
		return
	}

	filtered := make([]Question, 0, len(items))
	for _, item := range items {
		if subjectFilter != "" && !strings.EqualFold(item.Subject, subjectFilter) {
			continue
		}
		if sourceFilter != "" && !strings.EqualFold(string(item.Source), sourceFilter) {
			continue
		}
		filtered = append(filtered, item)
	}
	httpx.WriteJSON(w, http.StatusOK, filtered)
}

func (h *Handler) update(w http.ResponseWriter, r *http.Request) {
	var req UpdateInput
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}

	item, err := h.service.Update(r.Context(), chi.URLParam(r, "id"), req)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, item)
}

func (h *Handler) delete(w http.ResponseWriter, r *http.Request) {
	if err := h.service.Delete(r.Context(), chi.URLParam(r, "id")); err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]string{"status": "deleted"})
}
