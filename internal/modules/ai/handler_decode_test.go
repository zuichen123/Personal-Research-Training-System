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

