package profile

import (
	"fmt"
	"net/http"

	"github.com/go-chi/chi/v5"
	"self-study-tool/internal/shared/httpx"
)

type Handler struct {
	service            *Service
	onboardingService  *OnboardingService
}

func NewHandler(service *Service, onboardingService *OnboardingService) *Handler {
	return &Handler{
		service:           service,
		onboardingService: onboardingService,
	}
}

func (h *Handler) RegisterRoutes(r chi.Router) {
	r.Get("/profile", h.get)
	r.Put("/profile", h.upsert)
	r.Get("/profile/onboarding/next", h.getNextQuestion)
	r.Post("/profile/onboarding/answer", h.saveAnswer)
	r.Post("/profile/onboarding/complete", h.completeOnboarding)
}

func (h *Handler) get(w http.ResponseWriter, r *http.Request) {
	item, err := h.service.Get(r.Context(), r.URL.Query().Get("user_id"))
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, item)
}

func (h *Handler) upsert(w http.ResponseWriter, r *http.Request) {
	var req UpsertInput
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}
	item, err := h.service.Upsert(r.Context(), req)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, item)
}

func (h *Handler) getNextQuestion(w http.ResponseWriter, r *http.Request) {
	userID := r.URL.Query().Get("user_id")
	if userID == "" {
		httpx.WriteError(w, httpx.NewError(http.StatusBadRequest, "user_id required"))
		return
	}

	state, err := h.onboardingService.GetState(r.Context(), parseUserID(userID))
	if err != nil {
		state = &OnboardingState{CurrentStep: 0}
	}

	question, err := h.onboardingService.GetNextQuestion(r.Context(), parseUserID(userID), state.CurrentStep)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, question)
}

func (h *Handler) saveAnswer(w http.ResponseWriter, r *http.Request) {
	var req struct {
		UserID   string `json:"user_id"`
		Step     int    `json:"step"`
		Response string `json:"response"`
	}
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}

	if err := h.onboardingService.SaveResponse(r.Context(), parseUserID(req.UserID), req.Step, req.Response); err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]bool{"success": true})
}

func (h *Handler) completeOnboarding(w http.ResponseWriter, r *http.Request) {
	var req struct {
		UserID string `json:"user_id"`
	}
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}

	if err := h.onboardingService.CompleteOnboarding(r.Context(), parseUserID(req.UserID)); err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]bool{"success": true})
}

func parseUserID(userID string) int64 {
	var id int64
	fmt.Sscanf(userID, "%d", &id)
	return id
}
