package ai

import (
	"net/http"
	"strconv"

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
	r.Route("/ai", func(r chi.Router) {
		r.Post("/questions/generate", h.generate)
		r.Post("/grade", h.grade)
	})
}

func (h *Handler) generate(w http.ResponseWriter, r *http.Request) {
	var req GenerateRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}

	persist, _ := strconv.ParseBool(r.URL.Query().Get("persist"))
	items, err := h.service.Generate(r.Context(), req, persist)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, items)
}

func (h *Handler) grade(w http.ResponseWriter, r *http.Request) {
	var req GradeRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}

	result, err := h.service.Grade(r.Context(), req)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, result)
}
