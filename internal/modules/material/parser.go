package material

import (
	"context"
	"fmt"
	"path/filepath"
	"strings"
)

type ParserService struct {
	aiClient AIClient
}

type AIClient interface {
	Chat(ctx context.Context, req ChatRequest) (ChatResponse, error)
}

type ChatRequest struct {
	Messages []ChatMessage
}

type ChatMessage struct {
	Role    string
	Content string
}

type ChatResponse struct {
	Content string
}

type ParsedMaterial struct {
	Title    string
	Subject  string
	Content  string
	Format   string
	Metadata map[string]string
}

func NewParserService(aiClient AIClient) *ParserService {
	return &ParserService{aiClient: aiClient}
}

func (s *ParserService) ParseFile(ctx context.Context, filename, content string) (*ParsedMaterial, error) {
	ext := strings.ToLower(filepath.Ext(filename))
	format := s.detectFormat(ext)

	material := &ParsedMaterial{
		Title:    filename,
		Content:  content,
		Format:   format,
		Metadata: make(map[string]string),
	}

	subject, err := s.classifySubject(ctx, content)
	if err == nil {
		material.Subject = subject
	}

	return material, nil
}

func (s *ParserService) detectFormat(ext string) string {
	switch ext {
	case ".pdf":
		return "pdf"
	case ".jpg", ".jpeg", ".png", ".gif":
		return "image"
	case ".mobi", ".epub":
		return "ebook"
	case ".txt", ".md":
		return "text"
	default:
		return "unknown"
	}
}

func (s *ParserService) classifySubject(ctx context.Context, content string) (string, error) {
	if len(content) > 1000 {
		content = content[:1000]
	}

	prompt := fmt.Sprintf(`分析以下学习资料内容，判断所属科目（数学/英语/物理/化学/生物/历史/地理/政治/语文/其他）：

%s

只返回科目名称。`, content)

	resp, err := s.aiClient.Chat(ctx, ChatRequest{
		Messages: []ChatMessage{{Role: "user", Content: prompt}},
	})
	if err != nil {
		return "", err
	}

	return strings.TrimSpace(resp.Content), nil
}
