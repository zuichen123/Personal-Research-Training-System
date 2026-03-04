package ai

import (
	"net/http/httptest"
	"strings"
	"testing"
)

func TestDecodeGradeRequest_NewSchema(t *testing.T) {
	r := httptest.NewRequest("POST", "/ai/grade", strings.NewReader(`{
		"question": {
			"id": "q1",
			"title": "t",
			"stem": "s",
			"type": "short_answer",
			"subject": "math",
			"source": "unit_test",
			"answer_key": ["a1"],
			"difficulty": 1,
			"mastery_level": 0
		},
		"user_answer": ["u1"]
	}`))

	req, err := decodeGradeRequest(r)
	if err != nil {
		t.Fatalf("decode new schema failed: %v", err)
	}
	if req.Question.ID != "q1" {
		t.Fatalf("unexpected question id: %s", req.Question.ID)
	}
	if len(req.UserAnswer) != 1 || req.UserAnswer[0] != "u1" {
		t.Fatalf("unexpected user answer: %#v", req.UserAnswer)
	}
}

func TestDecodeGradeRequest_LegacySchema(t *testing.T) {
	r := httptest.NewRequest("POST", "/ai/grade", strings.NewReader(`{
		"question_id": "q2",
		"question": "what is 1+1",
		"user_answer": "2",
		"answer_key": ["2"],
		"question_type": "short_answer"
	}`))

	req, err := decodeGradeRequest(r)
	if err != nil {
		t.Fatalf("decode legacy schema failed: %v", err)
	}
	if req.Question.ID != "q2" {
		t.Fatalf("unexpected question id: %s", req.Question.ID)
	}
	if req.Question.Stem != "what is 1+1" {
		t.Fatalf("unexpected question stem: %s", req.Question.Stem)
	}
	if len(req.Question.AnswerKey) != 1 || req.Question.AnswerKey[0] != "2" {
		t.Fatalf("unexpected answer key: %#v", req.Question.AnswerKey)
	}
	if len(req.UserAnswer) != 1 || req.UserAnswer[0] != "2" {
		t.Fatalf("unexpected user answer: %#v", req.UserAnswer)
	}
}

func TestDecodeGradeRequest_InvalidPayload(t *testing.T) {
	r := httptest.NewRequest("POST", "/ai/grade", strings.NewReader(`{
		"question": 123,
		"user_answer": ["x"]
	}`))

	_, err := decodeGradeRequest(r)
	if err == nil {
		t.Fatal("expected decode error")
	}
}

func TestDecodeGradeRequest_AllowsAttachmentOnlyAnswer(t *testing.T) {
	r := httptest.NewRequest("POST", "/ai/grade", strings.NewReader(`{
		"question": {
			"id": "q1",
			"title": "t",
			"stem": "s",
			"type": "short_answer",
			"subject": "math",
			"source": "unit_test",
			"answer_key": ["a1"],
			"difficulty": 1,
			"mastery_level": 0
		},
		"attachments": [
			{
				"name": "handwrite.png",
				"mime_type": "image/png",
				"data_url": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA"
			}
		]
	}`))

	req, err := decodeGradeRequest(r)
	if err != nil {
		t.Fatalf("decode attachment-only schema failed: %v", err)
	}
	if len(req.Attachments) != 1 {
		t.Fatalf("expected 1 attachment, got %d", len(req.Attachments))
	}
	if len(req.UserAnswer) != 0 {
		t.Fatalf("expected empty user answer, got %#v", req.UserAnswer)
	}
}

func TestDecodeGradeRequest_AllowsAudioAttachmentOnlyAnswer(t *testing.T) {
	r := httptest.NewRequest("POST", "/ai/grade", strings.NewReader(`{
		"question": {
			"id": "q1",
			"title": "t",
			"stem": "s",
			"type": "short_answer",
			"subject": "english",
			"source": "unit_test",
			"answer_key": ["a1"],
			"difficulty": 1,
			"mastery_level": 0
		},
		"attachments": [
			{
				"name": "voice.wav",
				"mime_type": "audio/wav",
				"data_url": "data:audio/wav;base64,UklGRhQAAABXQVZF"
			}
		]
	}`))

	req, err := decodeGradeRequest(r)
	if err != nil {
		t.Fatalf("decode audio-attachment schema failed: %v", err)
	}
	if len(req.Attachments) != 1 {
		t.Fatalf("expected 1 attachment, got %d", len(req.Attachments))
	}
	if req.Attachments[0].MimeType != "audio/wav" {
		t.Fatalf("unexpected mime type: %s", req.Attachments[0].MimeType)
	}
	if len(req.UserAnswer) != 0 {
		t.Fatalf("expected empty user answer, got %#v", req.UserAnswer)
	}
}
