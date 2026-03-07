package ai

import (
	"context"
	"testing"
)

func TestComputeMath_WithVariables(t *testing.T) {
	svc := &Service{}
	result, err := svc.ComputeMath(context.Background(), MathComputeRequest{
		Expression: "pow(x, 2) + sqrt(16) - y / 2",
		Variables: map[string]float64{
			"x": 3,
			"y": 4,
		},
		Precision: 3,
	})
	if err != nil {
		t.Fatalf("ComputeMath() error = %v", err)
	}
	if result.Formatted != "11.000" {
		t.Fatalf("expected formatted=11.000, got %s", result.Formatted)
	}
}

func TestComputeMath_InvalidExpression(t *testing.T) {
	svc := &Service{}
	_, err := svc.ComputeMath(context.Background(), MathComputeRequest{
		Expression: "1 + (2 *",
	})
	if err == nil {
		t.Fatal("expected error for invalid expression")
	}
}

func TestVerifyMathAnswer_Numeric(t *testing.T) {
	svc := &Service{}
	result, err := svc.VerifyMathAnswer(context.Background(), MathVerifyRequest{
		Question:        "计算 2/3 的值",
		CandidateAnswer: "2/3",
		ReferenceAnswer: "0.6666666667",
		SolutionProcess: "先做除法，得到约等于 0.6666666667。",
	})
	if err != nil {
		t.Fatalf("VerifyMathAnswer() error = %v", err)
	}
	if !result.Correct {
		t.Fatalf("expected correct=true, got false: %+v", result)
	}
	if !result.ProcessValid {
		t.Fatalf("expected process valid, got false: %+v", result)
	}
}

func TestVerifyMathAnswer_OpenQuestionNotUnique(t *testing.T) {
	svc := &Service{}
	result, err := svc.VerifyMathAnswer(context.Background(), MathVerifyRequest{
		Question:        "举例说明一个你喜欢的函数并给出理由",
		CandidateAnswer: "y=x^2",
		ReferenceAnswer: "",
		SolutionProcess: "给出二次函数作为例子并解释图像特征。",
	})
	if err != nil {
		t.Fatalf("VerifyMathAnswer() error = %v", err)
	}
	if result.UniqueAnswer {
		t.Fatalf("expected unique_answer=false for open question: %+v", result)
	}
}
