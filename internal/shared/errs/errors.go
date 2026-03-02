package errs

import "net/http"

type AppError struct {
	Code       string `json:"code"`
	Message    string `json:"message"`
	HTTPStatus int    `json:"-"`
}

func (e *AppError) Error() string {
	return e.Message
}

func New(code, message string, status int) *AppError {
	return &AppError{Code: code, Message: message, HTTPStatus: status}
}

func Internal(message string) *AppError {
	return New("internal_error", message, http.StatusInternalServerError)
}

func BadRequest(message string) *AppError {
	return New("bad_request", message, http.StatusBadRequest)
}

func NotFound(message string) *AppError {
	return New("not_found", message, http.StatusNotFound)
}

func Conflict(message string) *AppError {
	return New("conflict", message, http.StatusConflict)
}

func FromError(err error) *AppError {
	if err == nil {
		return nil
	}
	if appErr, ok := err.(*AppError); ok {
		return appErr
	}
	return Internal(err.Error())
}
