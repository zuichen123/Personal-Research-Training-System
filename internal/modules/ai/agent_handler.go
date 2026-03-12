package ai

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"
	"prts/internal/shared/httpx"
)

func (h *Handler) listAgents(w http.ResponseWriter, r *http.Request) {
	items, err := h.service.ListAgents(r.Context())
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, items)
}

func (h *Handler) createAgent(w http.ResponseWriter, r *http.Request) {
	var req UpsertAgentRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}
	item, err := h.service.CreateAgent(r.Context(), req)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusCreated, item)
}

func (h *Handler) updateAgent(w http.ResponseWriter, r *http.Request) {
	var req UpsertAgentRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}
	item, err := h.service.UpdateAgent(r.Context(), strings.TrimSpace(chi.URLParam(r, "id")), req)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, item)
}

func (h *Handler) deleteAgent(w http.ResponseWriter, r *http.Request) {
	if err := h.service.DeleteAgent(r.Context(), strings.TrimSpace(chi.URLParam(r, "id"))); err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]string{"status": "deleted"})
}

func (h *Handler) listAgentSessions(w http.ResponseWriter, r *http.Request) {
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	cursor := strings.TrimSpace(r.URL.Query().Get("cursor"))
	items, err := h.service.ListAgentSessions(
		r.Context(),
		strings.TrimSpace(chi.URLParam(r, "id")),
		limit,
		cursor,
	)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, items)
}

func (h *Handler) createAgentSession(w http.ResponseWriter, r *http.Request) {
	var req CreateSessionRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}
	item, err := h.service.CreateAgentSession(
		r.Context(),
		strings.TrimSpace(chi.URLParam(r, "id")),
		req,
	)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusCreated, item)
}

func (h *Handler) deleteAgentSession(w http.ResponseWriter, r *http.Request) {
	if err := h.service.DeleteAgentSession(r.Context(), strings.TrimSpace(chi.URLParam(r, "id"))); err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]string{"status": "deleted"})
}

func (h *Handler) listSessionMessages(w http.ResponseWriter, r *http.Request) {
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	beforeID := strings.TrimSpace(r.URL.Query().Get("before_id"))
	items, err := h.service.ListSessionMessages(
		r.Context(),
		strings.TrimSpace(chi.URLParam(r, "id")),
		limit,
		beforeID,
	)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, items)
}

func (h *Handler) sendSessionMessage(w http.ResponseWriter, r *http.Request) {
	var req SendSessionMessageRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}
	sessionID := strings.TrimSpace(chi.URLParam(r, "id"))
	if h.maybeStreamOperation(w, r, "agent_chat", func() (any, error) {
		return h.service.SendSessionMessage(r.Context(), sessionID, req)
	}) {
		return
	}
	result, err := h.service.SendSessionMessage(
		r.Context(),
		sessionID,
		req,
	)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, result)
}

func (h *Handler) getSessionScheduleBinding(w http.ResponseWriter, r *http.Request) {
	item, err := h.service.GetSessionScheduleBinding(
		r.Context(),
		strings.TrimSpace(chi.URLParam(r, "id")),
	)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, item)
}

func (h *Handler) updateSessionScheduleBinding(w http.ResponseWriter, r *http.Request) {
	var req UpdateSessionScheduleBindingRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}
	item, err := h.service.UpdateSessionScheduleBinding(
		r.Context(),
		strings.TrimSpace(chi.URLParam(r, "id")),
		req,
	)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, item)
}

func (h *Handler) confirmSessionAction(w http.ResponseWriter, r *http.Request) {
	var req ConfirmActionRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}
	sessionID := strings.TrimSpace(chi.URLParam(r, "id"))
	if h.maybeStreamOperation(w, r, "agent_confirm_action", func() (any, error) {
		return h.service.ConfirmSessionAction(r.Context(), sessionID, req)
	}) {
		return
	}
	result, err := h.service.ConfirmSessionAction(
		r.Context(),
		sessionID,
		req,
	)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, result)
}

func (h *Handler) listSessionArtifacts(w http.ResponseWriter, r *http.Request) {
	status := strings.TrimSpace(r.URL.Query().Get("status"))
	items, err := h.service.ListSessionArtifacts(
		r.Context(),
		strings.TrimSpace(chi.URLParam(r, "id")),
		status,
	)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, items)
}

func (h *Handler) compressSessionMessages(w http.ResponseWriter, r *http.Request) {
	var req CompressSessionRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}
	result, err := h.service.CompressSessionMessages(
		r.Context(),
		strings.TrimSpace(chi.URLParam(r, "id")),
		req,
	)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, result)
}

func (h *Handler) importQuestionsFromArtifact(w http.ResponseWriter, r *http.Request) {
	var req ImportQuestionsRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}
	result, err := h.service.ImportQuestionsFromArtifact(
		r.Context(),
		strings.TrimSpace(chi.URLParam(r, "id")),
		req,
	)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, result)
}

func (h *Handler) importPlanFromArtifact(w http.ResponseWriter, r *http.Request) {
	var req ImportPlanRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}
	result, err := h.service.ImportPlanFromArtifact(
		r.Context(),
		strings.TrimSpace(chi.URLParam(r, "id")),
		req,
	)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, result)
}
