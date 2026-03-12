package mistake

import (
	"net/http"
	"sort"
	"strings"

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
	r.Route("/mistakes", func(r chi.Router) {
		r.Post("/", h.create)
		r.Get("/", h.list)
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
	items, err := h.service.List(r.Context(), r.URL.Query().Get("question_id"))
	if err != nil {
		httpx.WriteError(w, err)
		return
	}

	sortBy := strings.ToLower(strings.TrimSpace(r.URL.Query().Get("sort_by")))
	order := strings.ToLower(strings.TrimSpace(r.URL.Query().Get("order")))
	if order == "" {
		order = "desc"
	}

	switch sortBy {
	case "subject":
		sort.Slice(items, func(i, j int) bool {
			if order == "desc" {
				return items[i].Subject > items[j].Subject
			}
			return items[i].Subject < items[j].Subject
		})
	case "unit":
		sort.Slice(items, func(i, j int) bool {
			if order == "desc" {
				return items[i].Unit > items[j].Unit
			}
			return items[i].Unit < items[j].Unit
		})
	case "subject_unit":
		sort.Slice(items, func(i, j int) bool {
			if items[i].Subject != items[j].Subject {
				if order == "desc" {
					return items[i].Subject > items[j].Subject
				}
				return items[i].Subject < items[j].Subject
			}
			if items[i].Unit != items[j].Unit {
				if order == "desc" {
					return items[i].Unit > items[j].Unit
				}
				return items[i].Unit < items[j].Unit
			}
			return items[i].CreatedAt.After(items[j].CreatedAt)
		})
	case "difficulty":
		sort.Slice(items, func(i, j int) bool {
			if order == "desc" {
				return items[i].Difficulty > items[j].Difficulty
			}
			return items[i].Difficulty < items[j].Difficulty
		})
	case "created_at":
		sort.Slice(items, func(i, j int) bool {
			if order == "desc" {
				return items[i].CreatedAt.After(items[j].CreatedAt)
			}
			return items[i].CreatedAt.Before(items[j].CreatedAt)
		})
	default:
		sort.Slice(items, func(i, j int) bool {
			return items[i].CreatedAt.After(items[j].CreatedAt)
		})
	}

	httpx.WriteJSON(w, http.StatusOK, items)
}

func (h *Handler) delete(w http.ResponseWriter, r *http.Request) {
	if err := h.service.Delete(r.Context(), chi.URLParam(r, "id")); err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]string{"status": "deleted"})
}
