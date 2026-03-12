package schedule

import (
	"encoding/json"
	"net/http"
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
	r.Post("/schedule/generate", h.generate)
	r.Get("/schedule/daily", h.getDailySchedule)
	r.Post("/schedule/adjust", h.requestAdjustment)
}

func (h *Handler) generate(w http.ResponseWriter, r *http.Request) {
	var req struct {
		UserID      int64                  `json:"user_id"`
		UserProfile map[string]interface{} `json:"user_profile"`
	}
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}

	if err := h.service.GenerateSchedule(r.Context(), req.UserID, req.UserProfile); err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]bool{"success": true})
}

func (h *Handler) getDailySchedule(w http.ResponseWriter, r *http.Request) {
	userID := r.URL.Query().Get("user_id")
	date := r.URL.Query().Get("date")

	var uid int64
	json.Unmarshal([]byte(userID), &uid)

	schedules, err := h.service.GetDailySchedule(r.Context(), uid, date)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, schedules)
}

func (h *Handler) requestAdjustment(w http.ResponseWriter, r *http.Request) {
	var req struct {
		UserID         int64  `json:"user_id"`
		ScheduleID     int64  `json:"schedule_id"`
		Reason         string `json:"reason"`
		AdjustmentType string `json:"adjustment_type"`
	}
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}

	if err := h.service.RequestAdjustment(r.Context(), req.UserID, req.ScheduleID, req.Reason, req.AdjustmentType); err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]bool{"success": true})
}
