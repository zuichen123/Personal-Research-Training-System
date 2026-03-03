package httpx

import (
	"encoding/json"
	"io"
	"net/http"

	"self-study-tool/internal/platform/observability/logx"
	"self-study-tool/internal/shared/errs"
)

type SuccessResponse struct {
	Data any `json:"data"`
}

type ErrorResponse struct {
	Error *errs.AppError `json:"error"`
}

func WriteJSON(w http.ResponseWriter, status int, data any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(SuccessResponse{Data: data})
}

func WriteError(w http.ResponseWriter, err error) {
	appErr := errs.FromError(err)
	logx.L().Error("http handler returned error",
		"event", "http.request.error",
		"error_code", appErr.Code,
		"error_message", appErr.Message,
		"http_status", appErr.HTTPStatus,
	)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(appErr.HTTPStatus)
	_ = json.NewEncoder(w).Encode(ErrorResponse{Error: appErr})
}

func DecodeJSON(r *http.Request, out any) error {
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(out); err != nil {
		return errs.BadRequest("invalid json payload")
	}
	if err := decoder.Decode(&struct{}{}); err != io.EOF {
		return errs.BadRequest("invalid json payload")
	}
	return nil
}
