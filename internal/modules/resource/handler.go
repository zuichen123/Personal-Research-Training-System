package resource

import (
	"io"
	"net/http"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"
	"self-study-tool/internal/shared/errs"
	"self-study-tool/internal/shared/httpx"
)

type Handler struct {
	service        *Service
	maxUploadBytes int64
}

func NewHandler(service *Service, maxUploadBytes int64) *Handler {
	return &Handler{service: service, maxUploadBytes: maxUploadBytes}
}

func (h *Handler) RegisterRoutes(r chi.Router) {
	r.Route("/resources", func(r chi.Router) {
		r.Post("/", h.upload)
		r.Get("/", h.list)
		r.Get("/{id}", h.getMeta)
		r.Get("/{id}/download", h.download)
	})
}

func (h *Handler) upload(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, h.maxUploadBytes)
	if err := r.ParseMultipartForm(h.maxUploadBytes); err != nil {
		httpx.WriteError(w, errs.BadRequest("invalid multipart upload or file too large"))
		return
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		httpx.WriteError(w, errs.BadRequest("file field is required"))
		return
	}
	defer file.Close()

	data, err := io.ReadAll(file)
	if err != nil {
		httpx.WriteError(w, errs.BadRequest("failed to read uploaded file"))
		return
	}

	contentType := header.Header.Get("Content-Type")
	if contentType == "" && len(data) > 0 {
		contentType = http.DetectContentType(data)
	}

	item, err := h.service.Create(r.Context(), CreateInput{
		Filename:    header.Filename,
		ContentType: contentType,
		Category:    r.FormValue("category"),
		Tags:        splitCSV(r.FormValue("tags")),
		QuestionID:  r.FormValue("question_id"),
		Data:        data,
	})
	if err != nil {
		httpx.WriteError(w, err)
		return
	}

	item.Data = nil
	httpx.WriteJSON(w, http.StatusCreated, item)
}

func (h *Handler) list(w http.ResponseWriter, r *http.Request) {
	items, err := h.service.List(r.Context(), r.URL.Query().Get("question_id"))
	if err != nil {
		httpx.WriteError(w, err)
		return
	}

	for i := range items {
		items[i].Data = nil
	}
	httpx.WriteJSON(w, http.StatusOK, items)
}

func (h *Handler) getMeta(w http.ResponseWriter, r *http.Request) {
	item, err := h.service.GetByID(r.Context(), chi.URLParam(r, "id"))
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	item.Data = nil
	httpx.WriteJSON(w, http.StatusOK, item)
}

func (h *Handler) download(w http.ResponseWriter, r *http.Request) {
	item, err := h.service.GetByID(r.Context(), chi.URLParam(r, "id"))
	if err != nil {
		httpx.WriteError(w, err)
		return
	}

	w.Header().Set("Content-Type", item.ContentType)
	w.Header().Set("Content-Disposition", `attachment; filename="`+sanitizeFilename(item.Filename)+`"`)
	w.Header().Set("Content-Length", strconv.FormatInt(item.SizeBytes, 10))
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(item.Data)
}

func splitCSV(raw string) []string {
	if strings.TrimSpace(raw) == "" {
		return nil
	}
	parts := strings.Split(raw, ",")
	result := make([]string, 0, len(parts))
	for _, p := range parts {
		v := strings.TrimSpace(p)
		if v != "" {
			result = append(result, v)
		}
	}
	return result
}

func sanitizeFilename(name string) string {
	replacer := strings.NewReplacer("\r", "", "\n", "", `"`, "")
	return replacer.Replace(name)
}
