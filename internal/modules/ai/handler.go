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
		r.Get("/provider", h.providerStatus)
		r.Put("/provider/config", h.updateProviderConfig)
		r.Post("/questions/generate", h.generate)
		r.Get("/questions/search", h.searchOnline)
		r.Post("/grade", h.grade)
		r.Post("/learning", h.learning)
		r.Post("/evaluate", h.evaluate)
		r.Post("/score", h.score)
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

func (h *Handler) searchOnline(w http.ResponseWriter, r *http.Request) {
	topic := r.URL.Query().Get("topic")
	subject := r.URL.Query().Get("subject")
	count, _ := strconv.Atoi(r.URL.Query().Get("count"))
	if count <= 0 {
		count = 5
	}

	items, err := h.service.SearchOnlineQuestions(r.Context(), topic, subject, count)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, items)
}

func (h *Handler) learning(w http.ResponseWriter, r *http.Request) {
	var req LearnRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}

	result, err := h.service.Learn(r.Context(), req)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, result)
}

func (h *Handler) evaluate(w http.ResponseWriter, r *http.Request) {
	var req EvaluateRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}

	result, err := h.service.Evaluate(r.Context(), req)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, result)
}

func (h *Handler) score(w http.ResponseWriter, r *http.Request) {
	var req ScoreRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}

	result, err := h.service.Score(r.Context(), req)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, result)
}

func (h *Handler) providerStatus(w http.ResponseWriter, _ *http.Request) {
	httpx.WriteJSON(w, http.StatusOK, h.service.ProviderStatus())
}

func (h *Handler) updateProviderConfig(w http.ResponseWriter, r *http.Request) {
	var req UpdateProviderConfigRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}
	status, err := h.service.UpdateProviderConfig(req)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, status)
}
