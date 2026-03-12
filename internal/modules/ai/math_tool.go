package ai

import (
	"context"
	"fmt"
	"math"
	"strconv"
	"strings"
	"unicode"

	"prts/internal/shared/errs"
)

func (s *Service) ComputeMath(_ context.Context, req MathComputeRequest) (MathComputeResult, error) {
	expr := normalizeMathExpression(req.Expression)
	if expr == "" {
		return MathComputeResult{}, errs.BadRequest("expression is required")
	}

	precision := req.Precision
	if precision == 0 {
		precision = 6
	}
	if precision < 0 || precision > 12 {
		return MathComputeResult{}, errs.BadRequest("precision must be in [0, 12]")
	}

	vars := normalizeMathVariables(req.Variables)
	value, err := evalMathExpression(expr, vars)
	if err != nil {
		return MathComputeResult{}, errs.BadRequest(fmt.Sprintf("invalid math expression: %v", err))
	}

	return MathComputeResult{
		Expression: expr,
		Variables:  vars,
		Value:      value,
		Formatted:  strconv.FormatFloat(value, 'f', precision, 64),
		Precision:  precision,
	}, nil
}

func (s *Service) VerifyMathAnswer(_ context.Context, req MathVerifyRequest) (MathVerifyResult, error) {
	question := strings.TrimSpace(req.Question)
	candidate := normalizeMathExpression(req.CandidateAnswer)
	reference := normalizeMathExpression(req.ReferenceAnswer)
	process := strings.TrimSpace(req.SolutionProcess)
	if question == "" {
		return MathVerifyResult{}, errs.BadRequest("question is required")
	}
	if candidate == "" {
		return MathVerifyResult{}, errs.BadRequest("candidate_answer is required")
	}

	correct := false
	confidence := 0.55
	normalizedRef := reference
	if reference != "" {
		candidateValue, candidateIsNumber := parseNumberish(candidate)
		referenceValue, referenceIsNumber := parseNumberish(reference)
		if candidateIsNumber && referenceIsNumber {
			diff := math.Abs(candidateValue - referenceValue)
			eps := 1e-6 * math.Max(1, math.Abs(referenceValue))
			correct = diff <= eps
			confidence = 0.96
			normalizedRef = strconv.FormatFloat(referenceValue, 'g', 12, 64)
		} else {
			correct = normalizeComparableText(candidate) == normalizeComparableText(reference)
			confidence = 0.82
		}
	}

	processValid := len([]rune(process)) >= 8 || strings.Contains(process, "=")
	difficulty := estimateQuestionDifficulty(question)
	unique := isLikelyUniqueAnswer(question)

	summary := "已完成答案验证。"
	if reference == "" {
		summary = "未提供参考答案，已返回过程有效性和题目难度评估。"
		confidence = 0.45
	} else if correct {
		summary = "答案与参考答案一致。"
	} else {
		summary = "答案与参考答案不一致。"
	}

	return MathVerifyResult{
		Correct:       correct,
		Difficulty:    difficulty,
		UniqueAnswer:  unique,
		ProcessValid:  processValid,
		Confidence:    math.Round(confidence*100) / 100,
		Summary:       summary,
		NormalizedRef: normalizedRef,
	}, nil
}

func normalizeMathVariables(in map[string]float64) map[string]float64 {
	if len(in) == 0 {
		return map[string]float64{}
	}
	out := make(map[string]float64, len(in))
	for key, value := range in {
		name := strings.ToLower(strings.TrimSpace(key))
		if name == "" {
			continue
		}
		out[name] = value
	}
	return out
}

func normalizeMathExpression(expr string) string {
	text := strings.TrimSpace(expr)
	replacer := strings.NewReplacer(
		"（", "(",
		"）", ")",
		"，", ",",
		"。", ".",
		"＋", "+",
		"－", "-",
		"−", "-",
		"×", "*",
		"÷", "/",
		"＾", "^",
		"％", "%",
	)
	text = replacer.Replace(text)
	text = strings.TrimPrefix(text, "=")
	text = strings.TrimSpace(text)
	return text
}

func normalizeComparableText(text string) string {
	text = strings.ToLower(strings.TrimSpace(text))
	var b strings.Builder
	b.Grow(len(text))
	for _, r := range text {
		if unicode.IsSpace(r) {
			continue
		}
		switch r {
		case ',', '.', ';', ':', '，', '。', '；', '：':
			continue
		}
		b.WriteRune(r)
	}
	return b.String()
}

func parseNumberish(text string) (float64, bool) {
	trimmed := normalizeMathExpression(text)
	if trimmed == "" {
		return 0, false
	}
	if value, err := strconv.ParseFloat(trimmed, 64); err == nil {
		return value, true
	}
	value, err := evalMathExpression(trimmed, map[string]float64{})
	if err != nil {
		return 0, false
	}
	return value, true
}

func estimateQuestionDifficulty(question string) int {
	score := 1
	text := strings.ToLower(strings.TrimSpace(question))
	if len([]rune(text)) > 40 {
		score++
	}
	if len([]rune(text)) > 100 {
		score++
	}
	operatorCount := 0
	for _, r := range text {
		switch r {
		case '+', '-', '*', '/', '^', '(', ')', '=':
			operatorCount++
		}
	}
	if operatorCount >= 4 {
		score++
	}
	if operatorCount >= 8 {
		score++
	}
	if strings.Contains(text, "导数") ||
		strings.Contains(text, "积分") ||
		strings.Contains(text, "矩阵") ||
		strings.Contains(text, "极限") ||
		strings.Contains(text, "概率") {
		score++
	}
	if score < 1 {
		score = 1
	}
	if score > 5 {
		score = 5
	}
	return score
}

func isLikelyUniqueAnswer(question string) bool {
	text := strings.ToLower(strings.TrimSpace(question))
	nonUniqueHints := []string{
		"举例",
		"任选",
		"任意",
		"开放",
		"论述",
		"说明理由",
		"可能",
		"写出一种",
	}
	for _, hint := range nonUniqueHints {
		if strings.Contains(text, hint) {
			return false
		}
	}
	return true
}

func evalMathExpression(expression string, vars map[string]float64) (float64, error) {
	parser := &mathExprParser{
		input: strings.TrimSpace(expression),
		vars:  vars,
	}
	value, err := parser.parseExpression()
	if err != nil {
		return 0, err
	}
	parser.skipSpaces()
	if !parser.end() {
		return 0, fmt.Errorf("unexpected token at position %d", parser.pos+1)
	}
	if math.IsNaN(value) || math.IsInf(value, 0) {
		return 0, fmt.Errorf("result is not finite")
	}
	return value, nil
}

type mathExprParser struct {
	input string
	pos   int
	vars  map[string]float64
}

func (p *mathExprParser) parseExpression() (float64, error) {
	left, err := p.parseTerm()
	if err != nil {
		return 0, err
	}
	for {
		p.skipSpaces()
		switch {
		case p.match('+'):
			right, err := p.parseTerm()
			if err != nil {
				return 0, err
			}
			left += right
		case p.match('-'):
			right, err := p.parseTerm()
			if err != nil {
				return 0, err
			}
			left -= right
		default:
			return left, nil
		}
	}
}

func (p *mathExprParser) parseTerm() (float64, error) {
	left, err := p.parsePower()
	if err != nil {
		return 0, err
	}
	for {
		p.skipSpaces()
		if p.lookahead("**") {
			return left, nil
		}
		switch {
		case p.match('*'):
			right, err := p.parsePower()
			if err != nil {
				return 0, err
			}
			left *= right
		case p.match('/'):
			right, err := p.parsePower()
			if err != nil {
				return 0, err
			}
			if right == 0 {
				return 0, fmt.Errorf("division by zero")
			}
			left /= right
		default:
			return left, nil
		}
	}
}

func (p *mathExprParser) parsePower() (float64, error) {
	base, err := p.parseUnary()
	if err != nil {
		return 0, err
	}
	p.skipSpaces()
	if p.match('^') || p.matchString("**") {
		exp, err := p.parsePower()
		if err != nil {
			return 0, err
		}
		base = math.Pow(base, exp)
	}
	return base, nil
}

func (p *mathExprParser) parseUnary() (float64, error) {
	p.skipSpaces()
	if p.match('+') {
		return p.parseUnary()
	}
	if p.match('-') {
		value, err := p.parseUnary()
		if err != nil {
			return 0, err
		}
		return -value, nil
	}
	return p.parsePrimary()
}

func (p *mathExprParser) parsePrimary() (float64, error) {
	p.skipSpaces()
	if p.match('(') {
		value, err := p.parseExpression()
		if err != nil {
			return 0, err
		}
		p.skipSpaces()
		if !p.match(')') {
			return 0, fmt.Errorf("missing closing parenthesis")
		}
		return value, nil
	}
	if p.end() {
		return 0, fmt.Errorf("unexpected end of expression")
	}
	ch := p.peek()
	if isDigit(ch) || ch == '.' {
		return p.parseNumber()
	}
	if isIdentStart(ch) {
		ident := p.parseIdentifier()
		p.skipSpaces()
		if p.match('(') {
			args, err := p.parseFunctionArgs()
			if err != nil {
				return 0, err
			}
			return applyMathFunction(ident, args)
		}
		name := strings.ToLower(ident)
		switch name {
		case "pi":
			return math.Pi, nil
		case "e":
			return math.E, nil
		}
		if value, ok := p.vars[name]; ok {
			return value, nil
		}
		return 0, fmt.Errorf("unknown variable: %s", ident)
	}
	return 0, fmt.Errorf("unexpected token: %q", string(ch))
}

func (p *mathExprParser) parseFunctionArgs() ([]float64, error) {
	p.skipSpaces()
	if p.match(')') {
		return []float64{}, nil
	}
	args := []float64{}
	for {
		value, err := p.parseExpression()
		if err != nil {
			return nil, err
		}
		args = append(args, value)
		p.skipSpaces()
		if p.match(')') {
			return args, nil
		}
		if !p.match(',') {
			return nil, fmt.Errorf("expected ',' or ')' in function arguments")
		}
	}
}

func applyMathFunction(name string, args []float64) (float64, error) {
	switch strings.ToLower(strings.TrimSpace(name)) {
	case "sqrt":
		if len(args) != 1 {
			return 0, fmt.Errorf("sqrt expects 1 argument")
		}
		if args[0] < 0 {
			return 0, fmt.Errorf("sqrt domain error")
		}
		return math.Sqrt(args[0]), nil
	case "abs":
		if len(args) != 1 {
			return 0, fmt.Errorf("abs expects 1 argument")
		}
		return math.Abs(args[0]), nil
	case "sin":
		if len(args) != 1 {
			return 0, fmt.Errorf("sin expects 1 argument")
		}
		return math.Sin(args[0]), nil
	case "cos":
		if len(args) != 1 {
			return 0, fmt.Errorf("cos expects 1 argument")
		}
		return math.Cos(args[0]), nil
	case "tan":
		if len(args) != 1 {
			return 0, fmt.Errorf("tan expects 1 argument")
		}
		return math.Tan(args[0]), nil
	case "ln":
		if len(args) != 1 {
			return 0, fmt.Errorf("ln expects 1 argument")
		}
		if args[0] <= 0 {
			return 0, fmt.Errorf("ln domain error")
		}
		return math.Log(args[0]), nil
	case "log":
		if len(args) != 1 {
			return 0, fmt.Errorf("log expects 1 argument")
		}
		if args[0] <= 0 {
			return 0, fmt.Errorf("log domain error")
		}
		return math.Log10(args[0]), nil
	case "exp":
		if len(args) != 1 {
			return 0, fmt.Errorf("exp expects 1 argument")
		}
		return math.Exp(args[0]), nil
	case "pow":
		if len(args) != 2 {
			return 0, fmt.Errorf("pow expects 2 arguments")
		}
		return math.Pow(args[0], args[1]), nil
	case "max":
		if len(args) != 2 {
			return 0, fmt.Errorf("max expects 2 arguments")
		}
		return math.Max(args[0], args[1]), nil
	case "min":
		if len(args) != 2 {
			return 0, fmt.Errorf("min expects 2 arguments")
		}
		return math.Min(args[0], args[1]), nil
	case "floor":
		if len(args) != 1 {
			return 0, fmt.Errorf("floor expects 1 argument")
		}
		return math.Floor(args[0]), nil
	case "ceil":
		if len(args) != 1 {
			return 0, fmt.Errorf("ceil expects 1 argument")
		}
		return math.Ceil(args[0]), nil
	case "round":
		if len(args) != 1 {
			return 0, fmt.Errorf("round expects 1 argument")
		}
		return math.Round(args[0]), nil
	default:
		return 0, fmt.Errorf("unknown function: %s", name)
	}
}

func (p *mathExprParser) parseNumber() (float64, error) {
	start := p.pos
	dotSeen := false
	for !p.end() {
		ch := p.peek()
		if isDigit(ch) {
			p.pos++
			continue
		}
		if ch == '.' && !dotSeen {
			dotSeen = true
			p.pos++
			continue
		}
		break
	}
	if !p.end() && (p.peek() == 'e' || p.peek() == 'E') {
		p.pos++
		if !p.end() && (p.peek() == '+' || p.peek() == '-') {
			p.pos++
		}
		expStart := p.pos
		for !p.end() && isDigit(p.peek()) {
			p.pos++
		}
		if expStart == p.pos {
			return 0, fmt.Errorf("invalid scientific notation")
		}
	}
	text := strings.TrimSpace(p.input[start:p.pos])
	value, err := strconv.ParseFloat(text, 64)
	if err != nil {
		return 0, fmt.Errorf("invalid number: %s", text)
	}
	return value, nil
}

func (p *mathExprParser) parseIdentifier() string {
	start := p.pos
	for !p.end() {
		ch := p.peek()
		if isIdentPart(ch) {
			p.pos++
			continue
		}
		break
	}
	return p.input[start:p.pos]
}

func (p *mathExprParser) skipSpaces() {
	for !p.end() && unicode.IsSpace(rune(p.peek())) {
		p.pos++
	}
}

func (p *mathExprParser) match(ch byte) bool {
	p.skipSpaces()
	if p.end() || p.input[p.pos] != ch {
		return false
	}
	p.pos++
	return true
}

func (p *mathExprParser) matchString(token string) bool {
	p.skipSpaces()
	if p.end() {
		return false
	}
	if !strings.HasPrefix(p.input[p.pos:], token) {
		return false
	}
	p.pos += len(token)
	return true
}

func (p *mathExprParser) lookahead(token string) bool {
	p.skipSpaces()
	if p.end() {
		return false
	}
	return strings.HasPrefix(p.input[p.pos:], token)
}

func (p *mathExprParser) peek() byte {
	return p.input[p.pos]
}

func (p *mathExprParser) end() bool {
	return p.pos >= len(p.input)
}

func isDigit(ch byte) bool {
	return ch >= '0' && ch <= '9'
}

func isIdentStart(ch byte) bool {
	return (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ch == '_'
}

func isIdentPart(ch byte) bool {
	return isIdentStart(ch) || isDigit(ch)
}
