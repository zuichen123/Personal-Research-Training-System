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
		r.Delete("/attempts/{id}", h.deleteAttempt)
		r.Post("/generate-paper", h.generatePaper)
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
	items, err := h.service.ListAttemptsByQuestionID(r.Context(), r.URL.Query().Get("question_id"))
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, items)
}

func (h *Handler) deleteAttempt(w http.ResponseWriter, r *http.Request) {
	if err := h.service.DeleteAttempt(r.Context(), chi.URLParam(r, "id")); err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]string{"status": "deleted"})
}

func (h *Handler) generatePaper(w http.ResponseWriter, r *http.Request) {
	var req GeneratePaperRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}
	questions, err := h.service.GeneratePaper(r.Context(), req)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, questions)
}
