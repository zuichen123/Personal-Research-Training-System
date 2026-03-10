package ai

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"
	"self-study-tool/internal/modules/question"
	"self-study-tool/internal/shared/errs"
	"self-study-tool/internal/shared/httpx"
)

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) RegisterRoutes(r chi.Router) {
	r.Route("/ai", func(r chi.Router) {
		r.Get("/provider", h.providerStatus)
		r.Get("/provider/default-agent", h.defaultAgentProvider)
		r.Put("/provider/config", h.updateProviderConfig)
		r.Get("/prompts", h.listPromptTemplates)
		r.Put("/prompts/{key}", h.updatePromptTemplate)
		r.Post("/prompts/reload", h.reloadPromptTemplates)
		r.Get("/agents", h.listAgents)
		r.Post("/agents", h.createAgent)
		r.Put("/agents/{id}", h.updateAgent)
		r.Delete("/agents/{id}", h.deleteAgent)
		r.Get("/agents/{id}/sessions", h.listAgentSessions)
		r.Post("/agents/{id}/sessions", h.createAgentSession)
		r.Get("/sessions/{id}/messages", h.listSessionMessages)
		r.Post("/sessions/{id}/messages", h.sendSessionMessage)
		r.Get("/sessions/{id}/schedule-binding", h.getSessionScheduleBinding)
		r.Put("/sessions/{id}/schedule-binding", h.updateSessionScheduleBinding)
		r.Post("/sessions/{id}/confirm", h.confirmSessionAction)
		r.Post("/sessions/{id}/compress", h.compressSessionMessages)
		r.Get("/sessions/{id}/artifacts", h.listSessionArtifacts)
		r.Delete("/sessions/{id}", h.deleteAgentSession)
		r.Post("/artifacts/{id}/import/questions", h.importQuestionsFromArtifact)
		r.Post("/artifacts/{id}/import/plan", h.importPlanFromArtifact)
		r.Post("/questions/generate", h.generate)
		r.Get("/questions/search", h.searchOnline)
		r.Post("/grade", h.grade)
		r.Post("/learning", h.learning)
		r.Post("/learning/optimize", h.optimizeLearning)
		r.Post("/evaluate", h.evaluate)
		r.Post("/score", h.score)
		r.Post("/math/compute", h.mathCompute)
		r.Post("/math/verify", h.mathVerify)
		r.Post("/mistakes/analyze", h.analyzeMistakes)
		r.Get("/course-schedule/lessons", h.listCourseScheduleLessons)
		r.Post("/course-schedule/lessons", h.createCourseScheduleLesson)
		r.Put("/course-schedule/lessons/{id}", h.updateCourseScheduleLesson)
		r.Delete("/course-schedule/lessons/{id}", h.deleteCourseScheduleLesson)
	})
}

func (h *Handler) generate(w http.ResponseWriter, r *http.Request) {
	var req GenerateRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}

	persist, _ := strconv.ParseBool(r.URL.Query().Get("persist"))
	if h.maybeStreamOperation(w, r, "generate_questions", func() (any, error) {
		return h.service.Generate(r.Context(), req, persist)
	}) {
		return
	}
	items, err := h.service.Generate(r.Context(), req, persist)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, items)
}

func (h *Handler) grade(w http.ResponseWriter, r *http.Request) {
	req, err := decodeGradeRequest(r)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}

	if h.maybeStreamOperation(w, r, "grade", func() (any, error) {
		return h.service.Grade(r.Context(), req)
	}) {
		return
	}
	result, err := h.service.Grade(r.Context(), req)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, result)
}

func decodeGradeRequest(r *http.Request) (GradeRequest, error) {
	body, err := io.ReadAll(r.Body)
	if err != nil {
		return GradeRequest{}, errs.BadRequest("invalid json payload")
	}
	var raw map[string]json.RawMessage
	if err := json.Unmarshal(body, &raw); err != nil {
		return GradeRequest{}, errs.BadRequest("invalid json payload")
	}

	var req GradeRequest

	questionRaw, ok := raw["question"]
	if !ok {
		return GradeRequest{}, errs.BadRequest("question is required")
	}
	trimmedQuestion := bytes.TrimSpace(questionRaw)
	if len(trimmedQuestion) == 0 || bytes.Equal(trimmedQuestion, []byte("null")) {
		return GradeRequest{}, errs.BadRequest("question is required")
	}
	switch trimmedQuestion[0] {
	case '{':
		if err := json.Unmarshal(trimmedQuestion, &req.Question); err != nil {
			return GradeRequest{}, errs.BadRequest("invalid question payload")
		}
	case '"':
		var stem string
		if err := json.Unmarshal(trimmedQuestion, &stem); err != nil {
			return GradeRequest{}, errs.BadRequest("invalid question payload")
		}
		req.Question.Stem = strings.TrimSpace(stem)
	default:
		return GradeRequest{}, errs.BadRequest("invalid question payload")
	}

	if v, ok := raw["question_id"]; ok {
		var questionID string
		if err := json.Unmarshal(v, &questionID); err == nil {
			req.Question.ID = strings.TrimSpace(questionID)
		}
	}
	if v, ok := raw["answer_key"]; ok {
		var answerKey []string
		if err := json.Unmarshal(v, &answerKey); err == nil {
			req.Question.AnswerKey = answerKey
		}
	}
	if v, ok := raw["question_type"]; ok {
		var questionType string
		if err := json.Unmarshal(v, &questionType); err == nil {
			req.Question.Type = question.QuestionType(strings.TrimSpace(questionType))
		}
	}

	if v, ok := raw["attachments"]; ok {
		var attachments []ImageAttachment
		if err := json.Unmarshal(v, &attachments); err != nil {
			return GradeRequest{}, errs.BadRequest("invalid attachments payload")
		}
		normalized, err := normalizeImageAttachments(attachments)
		if err != nil {
			return GradeRequest{}, err
		}
		req.Attachments = normalized
	}

	userAnswerRaw, hasUserAnswer := raw["user_answer"]
	if hasUserAnswer {
		trimmedAnswer := bytes.TrimSpace(userAnswerRaw)
		if len(trimmedAnswer) > 0 && !bytes.Equal(trimmedAnswer, []byte("null")) {
			switch trimmedAnswer[0] {
			case '[':
				if err := json.Unmarshal(trimmedAnswer, &req.UserAnswer); err != nil {
					return GradeRequest{}, errs.BadRequest("invalid user_answer payload")
				}
			case '"':
				var answer string
				if err := json.Unmarshal(trimmedAnswer, &answer); err != nil {
					return GradeRequest{}, errs.BadRequest("invalid user_answer payload")
				}
				answer = strings.TrimSpace(answer)
				if answer != "" {
					req.UserAnswer = []string{answer}
				}
			default:
				return GradeRequest{}, errs.BadRequest("invalid user_answer payload")
			}
		}
	}
	if len(req.UserAnswer) == 0 && len(req.Attachments) == 0 {
		return GradeRequest{}, errs.BadRequest("user_answer or attachments is required")
	}

	return req, nil
}

func (h *Handler) searchOnline(w http.ResponseWriter, r *http.Request) {
	topic := r.URL.Query().Get("topic")
	subject := r.URL.Query().Get("subject")
	count, _ := strconv.Atoi(r.URL.Query().Get("count"))
	if count <= 0 {
		count = 5
	}

	items, err := h.service.SearchOnlineQuestions(r.Context(), topic, subject, count)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, items)
}

func (h *Handler) learning(w http.ResponseWriter, r *http.Request) {
	var req LearnRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}

	if h.maybeStreamOperation(w, r, "build_learning_plan", func() (any, error) {
		return h.service.Learn(r.Context(), req)
	}) {
		return
	}
	result, err := h.service.Learn(r.Context(), req)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, result)
}

func (h *Handler) optimizeLearning(w http.ResponseWriter, r *http.Request) {
	var req OptimizeLearnRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}

	if h.maybeStreamOperation(w, r, "optimize_learning_plan", func() (any, error) {
		return h.service.OptimizeLearningPlan(r.Context(), req)
	}) {
		return
	}
	result, err := h.service.OptimizeLearningPlan(r.Context(), req)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, result)
}

func (h *Handler) evaluate(w http.ResponseWriter, r *http.Request) {
	var req EvaluateRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}

	if h.maybeStreamOperation(w, r, "evaluate", func() (any, error) {
		return h.service.Evaluate(r.Context(), req)
	}) {
		return
	}
	result, err := h.service.Evaluate(r.Context(), req)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, result)
}

func (h *Handler) score(w http.ResponseWriter, r *http.Request) {
	var req ScoreRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}

	if h.maybeStreamOperation(w, r, "score", func() (any, error) {
		return h.service.Score(r.Context(), req)
	}) {
		return
	}
	result, err := h.service.Score(r.Context(), req)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, result)
}

func (h *Handler) mathCompute(w http.ResponseWriter, r *http.Request) {
	var req MathComputeRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}

	if h.maybeStreamOperation(w, r, "math_compute", func() (any, error) {
		return h.service.ComputeMath(r.Context(), req)
	}) {
		return
	}
	result, err := h.service.ComputeMath(r.Context(), req)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, result)
}

func (h *Handler) mathVerify(w http.ResponseWriter, r *http.Request) {
	var req MathVerifyRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}

	if h.maybeStreamOperation(w, r, "math_verify", func() (any, error) {
		return h.service.VerifyMathAnswer(r.Context(), req)
	}) {
		return
	}
	result, err := h.service.VerifyMathAnswer(r.Context(), req)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, result)
}

func (h *Handler) listCourseScheduleLessons(w http.ResponseWriter, r *http.Request) {
	query := CourseScheduleLessonListQuery{
		Date:        strings.TrimSpace(r.URL.Query().Get("date")),
		DateFrom:    strings.TrimSpace(r.URL.Query().Get("date_from")),
		DateTo:      strings.TrimSpace(r.URL.Query().Get("date_to")),
		Subject:     strings.TrimSpace(r.URL.Query().Get("subject")),
		Topic:       strings.TrimSpace(r.URL.Query().Get("topic")),
		Granularity: strings.TrimSpace(r.URL.Query().Get("granularity")),
	}
	items, err := h.service.ListCourseScheduleLessonsWithQuery(r.Context(), query)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, items)
}

func (h *Handler) createCourseScheduleLesson(w http.ResponseWriter, r *http.Request) {
	var req CourseScheduleLessonRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}
	item, err := h.service.CreateCourseScheduleLesson(r.Context(), req)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusCreated, item)
}

func (h *Handler) updateCourseScheduleLesson(w http.ResponseWriter, r *http.Request) {
	var req CourseScheduleLessonUpdateRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}
	item, err := h.service.UpdateCourseScheduleLesson(
		r.Context(),
		chi.URLParam(r, "id"),
		req,
	)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, item)
}

func (h *Handler) deleteCourseScheduleLesson(w http.ResponseWriter, r *http.Request) {
	if err := h.service.DeleteCourseScheduleLesson(r.Context(), chi.URLParam(r, "id")); err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]string{"status": "deleted"})
}

func (h *Handler) providerStatus(w http.ResponseWriter, _ *http.Request) {
	httpx.WriteJSON(w, http.StatusOK, h.service.ProviderStatus())
}

func (h *Handler) defaultAgentProvider(w http.ResponseWriter, _ *http.Request) {
	httpx.WriteJSON(w, http.StatusOK, h.service.DefaultAgentProvider())
}

func (h *Handler) updateProviderConfig(w http.ResponseWriter, r *http.Request) {
	var req UpdateProviderConfigRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}
	status, err := h.service.UpdateProviderConfig(req)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, status)
}

func (h *Handler) listPromptTemplates(w http.ResponseWriter, _ *http.Request) {
	httpx.WriteJSON(w, http.StatusOK, h.service.ListPromptTemplates())
}

func (h *Handler) updatePromptTemplate(w http.ResponseWriter, r *http.Request) {
	key := strings.TrimSpace(chi.URLParam(r, "key"))
	if key == "" {
		httpx.WriteError(w, errs.BadRequest("prompt key is required"))
		return
	}
	var req UpdatePromptTemplateRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}
	config, err := h.service.UpdatePromptTemplate(r.Context(), key, req)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, config)
}

func (h *Handler) reloadPromptTemplates(w http.ResponseWriter, r *http.Request) {
	configs, err := h.service.ReloadPromptTemplates(r.Context())
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, configs)
}

func (h *Handler) analyzeMistakes(w http.ResponseWriter, r *http.Request) {
	var req AnalyzeMistakesRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, err)
		return
	}
	result, err := h.service.AnalyzeMistakes(r.Context(), req)
	if err != nil {
		httpx.WriteError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, result)
}
