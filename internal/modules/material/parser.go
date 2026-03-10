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
	if len(content) > 2000 {
		content = content[:2000]
	}

	prompt := fmt.Sprintf(`# 角色定位
你是一位资深的教育内容分析专家，拥有10年以上的教材编写、课程设计与学习资料分类经验。你精通各学科知识体系、课程标准、教材结构，能够快速准确地识别学习资料的学科归属、知识层级、适用对象。

# 分析任务
请分析以下学习资料片段，精准判断其所属学科。

## 资料内容（前2000字符）
%s

# 学科分类体系

## 高中核心学科
1. **数学**：代数、几何、函数、导数、概率统计、数列、三角函数、解析几何等
2. **英语**：语法、词汇、阅读理解、写作、听力、翻译等
3. **物理**：力学、电磁学、光学、热学、原子物理、实验等
4. **化学**：无机化学、有机化学、化学反应、元素周期表、实验等
5. **生物**：细胞、遗传、进化、生态、人体生理、实验等
6. **语文**：现代文阅读、古诗文、文言文、作文、语言基础等
7. **历史**：中国古代史、中国近现代史、世界史、史料分析等
8. **地理**：自然地理、人文地理、区域地理、地图、环境等
9. **政治**：经济生活、政治生活、文化生活、哲学、时事等

## 其他分类
10. **综合**：跨学科内容、学习方法、考试技巧、心理辅导等
11. **未知**：无法明确判断学科归属

# 判断依据

## 关键词识别
- **数学**：方程、函数、导数、积分、向量、矩阵、概率、统计、证明
- **英语**：grammar、vocabulary、reading、writing、tense、clause
- **物理**：力、速度、加速度、能量、电流、电压、波、光、原子
- **化学**：元素、化合物、反应、氧化、还原、酸碱、有机物、实验
- **生物**：细胞、基因、DNA、蛋白质、光合作用、呼吸、遗传、进化
- **语文**：诗歌、散文、小说、文言文、修辞、字词、作文
- **历史**：朝代、事件、人物、年代、史料、改革、战争、文化
- **地理**：地形、气候、人口、城市、资源、环境、经纬度、地图
- **政治**：经济、政治、文化、哲学、唯物、辩证、价值观、制度

## 内容特征
- **公式密集**：数学、物理、化学
- **英文为主**：英语
- **图表地图**：地理、生物、化学
- **年代事件**：历史
- **理论观点**：政治、语文
- **实验步骤**：物理、化学、生物

## 语言风格
- **严谨逻辑**：数学、物理
- **描述性强**：生物、地理、历史
- **议论分析**：语文、政治
- **技术术语**：各理科

# 输出要求

请严格按照以下格式输出（只返回学科名称，不要其他内容）：

数学
或
英语
或
物理
或
化学
或
生物
或
语文
或
历史
或
地理
或
政治
或
综合
或
未知

# 判断原则
1. **精准性**：基于内容特征做出准确判断，避免模糊归类
2. **主导性**：如果涉及多学科，选择占比最大的主导学科
3. **专业性**：识别学科专业术语和知识体系特征
4. **保守性**：无法明确判断时，返回"未知"而非猜测

# 注意事项
1. 仅根据提供的内容片段判断，不要臆测完整内容
2. 关注学科特有的术语、符号、表达方式
3. 如果内容是目录、索引、封面等非正文内容，尝试从标题推断
4. 如果是跨学科综合材料（如学习方法、考试技巧），返回"综合"
5. 只返回学科名称，不要返回任何解释或分析`, content)

	resp, err := s.aiClient.Chat(ctx, ChatRequest{
		Messages: []ChatMessage{{Role: "user", Content: prompt}},
	})
	if err != nil {
		return "", err
	}

	return strings.TrimSpace(resp.Content), nil
}
