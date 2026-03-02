package clientui

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/widget"
)

type healthResponse struct {
	Data struct {
		Status string `json:"status"`
		Time   string `json:"time"`
	} `json:"data"`
}

type questionsResponse struct {
	Data []struct {
		ID         string   `json:"id"`
		Title      string   `json:"title"`
		Type       string   `json:"type"`
		Difficulty int      `json:"difficulty"`
		Tags       []string `json:"tags"`
	} `json:"data"`
}

func Run() {
	a := app.NewWithID("self-study-tool.desktop")
	w := a.NewWindow("Self Study Tool")
	w.Resize(fyne.NewSize(920, 620))

	baseURLInput := widget.NewEntry()
	baseURLInput.SetText("http://127.0.0.1:8080")
	baseURLInput.SetPlaceHolder("Backend base URL")

	statusLabel := widget.NewLabel("Status: idle")

	questionList := widget.NewMultiLineEntry()
	questionList.Disable()
	questionList.SetText("No data yet")

	httpClient := &http.Client{Timeout: 8 * time.Second}

	checkHealthBtn := widget.NewButton("Check Health", func() {
		baseURL := normalizeBaseURL(baseURLInput.Text)
		url := baseURL + "/api/v1/healthz"

		statusLabel.SetText("Status: checking health...")
		go func() {
			result, err := getHealth(httpClient, url)
			if err != nil {
				updateUI(a, func() {
					statusLabel.SetText("Status: health check failed - " + err.Error())
				})
				return
			}

			updateUI(a, func() {
				statusLabel.SetText(fmt.Sprintf("Status: %s (%s)", result.Status, result.Time))
			})
		}()
	})

	loadQuestionsBtn := widget.NewButton("Load Questions", func() {
		baseURL := normalizeBaseURL(baseURLInput.Text)
		url := baseURL + "/api/v1/questions"

		statusLabel.SetText("Status: loading questions...")
		go func() {
			items, err := getQuestions(httpClient, url)
			if err != nil {
				updateUI(a, func() {
					statusLabel.SetText("Status: load failed - " + err.Error())
				})
				return
			}

			text := renderQuestions(items)
			updateUI(a, func() {
				questionList.SetText(text)
				statusLabel.SetText(fmt.Sprintf("Status: loaded %d questions", len(items)))
			})
		}()
	})

	header := container.NewVBox(
		widget.NewLabelWithStyle("Cross-platform Client (Desktop/Android)", fyne.TextAlignLeading, fyne.TextStyle{Bold: true}),
		baseURLInput,
		container.NewGridWithColumns(2, checkHealthBtn, loadQuestionsBtn),
		statusLabel,
	)

	content := container.NewBorder(header, nil, nil, nil, questionList)
	w.SetContent(content)
	w.ShowAndRun()
}

func normalizeBaseURL(v string) string {
	t := strings.TrimSpace(v)
	t = strings.TrimSuffix(t, "/")
	if t == "" {
		return "http://127.0.0.1:8080"
	}
	return t
}

func getHealth(client *http.Client, url string) (struct {
	Status string
	Time   string
}, error) {
	var out struct {
		Status string
		Time   string
	}

	resp, err := client.Get(url)
	if err != nil {
		return out, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
		return out, fmt.Errorf("http %d: %s", resp.StatusCode, strings.TrimSpace(string(body)))
	}

	var parsed healthResponse
	if err := json.NewDecoder(resp.Body).Decode(&parsed); err != nil {
		return out, err
	}

	out.Status = parsed.Data.Status
	out.Time = parsed.Data.Time
	return out, nil
}

func getQuestions(client *http.Client, url string) ([]struct {
	ID         string
	Title      string
	Type       string
	Difficulty int
	Tags       []string
}, error) {
	resp, err := client.Get(url)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
		return nil, fmt.Errorf("http %d: %s", resp.StatusCode, strings.TrimSpace(string(body)))
	}

	var parsed questionsResponse
	if err := json.NewDecoder(resp.Body).Decode(&parsed); err != nil {
		return nil, err
	}

	result := make([]struct {
		ID         string
		Title      string
		Type       string
		Difficulty int
		Tags       []string
	}, 0, len(parsed.Data))

	for _, item := range parsed.Data {
		result = append(result, struct {
			ID         string
			Title      string
			Type       string
			Difficulty int
			Tags       []string
		}{
			ID:         item.ID,
			Title:      item.Title,
			Type:       item.Type,
			Difficulty: item.Difficulty,
			Tags:       item.Tags,
		})
	}

	return result, nil
}

func renderQuestions(items []struct {
	ID         string
	Title      string
	Type       string
	Difficulty int
	Tags       []string
}) string {
	if len(items) == 0 {
		return "No questions found"
	}

	var b strings.Builder
	for i, item := range items {
		b.WriteString(fmt.Sprintf("%d. %s\n", i+1, item.Title))
		b.WriteString(fmt.Sprintf("   id=%s\n", item.ID))
		b.WriteString(fmt.Sprintf("   type=%s, difficulty=%d\n", item.Type, item.Difficulty))
		if len(item.Tags) > 0 {
			b.WriteString(fmt.Sprintf("   tags=%s\n", strings.Join(item.Tags, ", ")))
		}
		b.WriteString("\n")
	}
	return b.String()
}

func updateUI(a fyne.App, fn func()) {
	_ = a
	fyne.Do(fn)
}
