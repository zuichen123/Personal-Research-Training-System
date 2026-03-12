package material

import (
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/go-chi/chi/v5"
	"prts/internal/shared/errs"
	"prts/internal/shared/httpx"
)

type Handler struct {
	service   *Service
	uploadDir string
}

func NewHandler(service *Service, uploadDir string) *Handler {
	return &Handler{
		service:   service,
		uploadDir: uploadDir,
	}
}

func (h *Handler) RegisterRoutes(r chi.Router) {
	r.Post("/materials/upload", h.Upload)
	r.Get("/materials", h.List)
	r.Get("/materials/{id}", h.GetByID)
	r.Put("/materials/{id}", h.Update)
	r.Delete("/materials/{id}", h.Delete)
}

func (h *Handler) Upload(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseMultipartForm(32 << 20); err != nil {
		httpx.WriteError(w, errs.BadRequest("parse form: "+err.Error()))
		return
	}
	file, header, err := r.FormFile("file")
	if err != nil {
		httpx.WriteError(w, errs.BadRequest("file is required"))
		return
	}
	defer file.Close()

	userID := r.FormValue("user_id")
	if userID == "" {
		userID = "default"
	}
	title := r.FormValue("title")
	if title == "" {
		title = header.Filename
	}
	subject := r.FormValue("subject")

	ext := strings.ToLower(filepath.Ext(header.Filename))
	fileType := detectFileType(ext)

	os.MkdirAll(h.uploadDir, 0755)
	destPath := filepath.Join(h.uploadDir, header.Filename)
	dest, err := os.Create(destPath)
	if err != nil {
		httpx.WriteError(w, errs.Internal("create file: "+err.Error()))
		return
	}
	defer dest.Close()

	if _, err := io.Copy(dest, file); err != nil {
		httpx.WriteError(w, errs.Internal("save file: "+err.Error()))
		return
	}

	contentText := ""
	if fileType == "text" {
		data, _ := os.ReadFile(destPath)
		contentText = string(data)
	}

	item, err := h.service.Create(r.Context(), CreateInput{
		UserID:      userID,
		Title:       title,
		FilePath:    destPath,
		FileType:    fileType,
		ContentText: contentText,
		Subject:     subject,
	})
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusCreated, item)
}

func (h *Handler) List(w http.ResponseWriter, r *http.Request) {
	userID := r.URL.Query().Get("user_id")
	subject := r.URL.Query().Get("subject")
	fileType := r.URL.Query().Get("file_type")
	keyword := r.URL.Query().Get("keyword")

	items, err := h.service.List(r.Context(), ListFilter{
		UserID:   userID,
		Subject:  subject,
		FileType: fileType,
		Keyword:  keyword,
	})
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, items)
}

func (h *Handler) GetByID(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	item, err := h.service.GetByID(r.Context(), id)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, item)
}

func (h *Handler) Update(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	var req UpdateInput
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}
	item, err := h.service.Update(r.Context(), id, req)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, item)
}

func (h *Handler) Delete(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if err := h.service.Delete(r.Context(), id); err != nil {
		httpx.WriteError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func detectFileType(ext string) string {
	switch ext {
	case ".pdf":
		return "pdf"
	case ".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp":
		return "image"
	case ".txt", ".md":
		return "text"
	case ".mobi", ".epub":
		return "ebook"
	default:
		return "other"
	}
}
