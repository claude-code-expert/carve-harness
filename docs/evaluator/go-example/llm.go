// Package judge — OpenAI 호환 API 호출 한 개. 앱 코드와 판사가 같이 쓴다.
// 실제 서비스: OPENAI_BASE_URL(예: https://api.openai.com/v1 또는 사내 vLLM), OPENAI_API_KEY 환경변수.
// 외부 모듈 없음(표준 라이브러리만). 실행: go test ./...
package judge

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strings"
	"time"
)

type Message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

func env(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

// Chat calls the chat/completions endpoint and returns the first message content.
func Chat(ctx context.Context, messages []Message, temperature float64, jsonMode bool) (string, error) {
	body := map[string]any{"model": env("LLM_MODEL", "gpt-4o-mini"), "messages": messages, "temperature": temperature}
	if jsonMode {
		body["response_format"] = map[string]string{"type": "json_object"}
	}
	b, _ := json.Marshal(body)
	url := strings.TrimRight(env("OPENAI_BASE_URL", "http://localhost:8000/v1"), "/") + "/chat/completions"
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(b))
	if err != nil {
		return "", fmt.Errorf("build request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+env("OPENAI_API_KEY", "none"))
	resp, err := (&http.Client{Timeout: 60 * time.Second}).Do(req)
	if err != nil {
		return "", fmt.Errorf("llm call: %w", err)
	}
	defer resp.Body.Close()
	var out struct {
		Choices []struct {
			Message Message `json:"message"`
		} `json:"choices"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil || len(out.Choices) == 0 {
		return "", fmt.Errorf("llm response: %v", err)
	}
	return out.Choices[0].Message.Content, nil
}
