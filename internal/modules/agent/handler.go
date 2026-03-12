package agent

import (
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"prts/internal/shared/httpx"
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
	r.Post("/agents/head-teacher", h.createHeadTeacher)
	r.Post("/agents/subject", h.createSubjectAgent)
	r.Post("/agents/{id}/bind-schedule", h.bindSchedule)
	r.Get("/agents/list", h.listAgents)
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

func (h *Handler) createHeadTeacher(w http.ResponseWriter, r *http.Request) {
	var req struct {
		UserID int64 `json:"user_id"`
	}
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}
	agent, err := h.service.CreateHeadTeacher(r.Context(), req.UserID)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusCreated, agent)
}

func (h *Handler) createSubjectAgent(w http.ResponseWriter, r *http.Request) {
	var req struct {
		UserID  int64  `json:"user_id"`
		Subject string `json:"subject"`
	}
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}
	agent, err := h.service.CreateSubjectAgent(r.Context(), req.UserID, req.Subject)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusCreated, agent)
}

func (h *Handler) bindSchedule(w http.ResponseWriter, r *http.Request) {
	agentID, _ := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	var req struct {
		ScheduleID int64 `json:"schedule_id"`
	}
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}
	if err := h.service.BindScheduleToAgent(r.Context(), agentID, req.ScheduleID); err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]bool{"success": true})
}

func (h *Handler) listAgents(w http.ResponseWriter, r *http.Request) {
	userID, _ := strconv.ParseInt(r.URL.Query().Get("user_id"), 10, 64)
	agents, err := h.service.ListAgents(r.Context(), userID)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, agents)
}
