package agent

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
	r.Post("/agents", h.create)
	r.Get("/agents/{type}", h.get)
	r.Post("/agents/{id}/dispatch", h.dispatch)
	r.Get("/agents/{id}/history", h.history)
}

func (h *Handler) create(w http.ResponseWriter, r *http.Request) {
	var req struct {
		UserID           int64  `json:"user_id"`
		Type             string `json:"type"`
		Subject          string `json:"subject"`
		Name             string `json:"name"`
		PromptTemplateID int64  `json:"prompt_template_id"`
	}
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}
	agent, err := h.service.CreateAgent(r.Context(), req.UserID, req.Type, req.Subject, req.Name, req.PromptTemplateID)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusCreated, agent)
}

func (h *Handler) get(w http.ResponseWriter, r *http.Request) {
	agentType := chi.URLParam(r, "type")
	userID, _ := strconv.ParseInt(r.URL.Query().Get("user_id"), 10, 64)
	agent, err := h.service.GetAgent(r.Context(), userID, agentType)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, agent)
}

func (h *Handler) dispatch(w http.ResponseWriter, r *http.Request) {
	id, _ := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	var req struct {
		Task string `json:"task"`
	}
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}
	if err := h.service.DispatchTask(r.Context(), id, req.Task); err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]bool{"success": true})
}

func (h *Handler) history(w http.ResponseWriter, r *http.Request) {
	id, _ := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	history, err := h.service.GetChatHistory(r.Context(), id, limit)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, history)
}
