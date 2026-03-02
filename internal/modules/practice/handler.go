package practice

import (
	"net/http"

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
	r.Route("/practice", func(r chi.Router) {
		r.Post("/submit", h.submit)
		r.Get("/attempts", h.listAttempts)
	})
}

func (h *Handler) submit(w http.ResponseWriter, r *http.Request) {
	var req SubmitInput
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}

	item, err := h.service.Submit(r.Context(), req)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusCreated, item)
}

func (h *Handler) listAttempts(w http.ResponseWriter, r *http.Request) {
	items, err := h.service.ListAttempts(r.Context())
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, items)
}
