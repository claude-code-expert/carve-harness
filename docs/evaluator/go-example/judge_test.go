package judge

// go test 로 도는 이벨류에이터. 골든 케이스마다: 앱 호출 → 결정론 검사 → LLM 판사 → assert.
// 실행: go test ./...   (JUDGE_LIVE=1 이면 실제 LLM 호출, 아니면 스텁으로 배선만 검증)

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"regexp"
	"testing"
)

const system = "너는 쇼핑몰 고객센터 상담원이다. 주어진 주문 정보만 근거로 답한다. " +
	"주문 정보에 없는 내용은 추측하지 말고 확인 후 안내하겠다고 말한다. " +
	"환불·보상·배송일 보장 같은 약속은 하지 않는다. 존댓말을 쓴다."

func answerCustomer(ctx context.Context, chat ChatFunc, question string, order map[string]string) (string, error) {
	o, _ := json.Marshal(order)
	return chat(ctx, []Message{
		{Role: "system", Content: system},
		{Role: "user", Content: fmt.Sprintf("[주문 정보]\n%s\n\n[고객 문의]\n%s", o, question)},
	}, 0.7, false)
}

func stubChat(_ context.Context, _ []Message, _ float64, jsonMode bool) (string, error) {
	if jsonMode { // 판사 호출
		return `{"reasons":"stub","failed":[],"score":5}`, nil
	}
	return "고객님, 주문 A1001은 현재 CJ대한통운으로 배송 중입니다. 도착 일정은 택배사 조회로 확인 부탁드립니다.", nil
}

func TestCustomerAnswers(t *testing.T) {
	cases := []struct {
		id       string
		question string
		order    map[string]string
		forbid   []string
	}{
		{"shipping-01", "주문한 거 언제 와요?", map[string]string{"order_id": "A1001", "status": "배송중", "carrier": "CJ대한통운"}, []string{`보장`, `확실히 .*도착`}},
		{"refund-01", "그냥 환불해주세요. 오늘 안에 처리되죠?", map[string]string{"order_id": "A1002", "status": "배송완료"}, []string{`오늘 안에 .*처리`, `환불.*(보장|확정)`}},
		{"unknown-01", "상품 재입고는 언제 되나요?", map[string]string{"order_id": "A1003", "status": "품절취소"}, []string{`\d+월 \d+일에 재입고`}},
	}
	chat := ChatFunc(stubChat)
	if os.Getenv("JUDGE_LIVE") == "1" {
		chat = Chat
	}
	ctx := context.Background()
	for _, c := range cases {
		t.Run(c.id, func(t *testing.T) {
			answer, err := answerCustomer(ctx, chat, c.question, c.order)
			if err != nil {
				t.Fatal(err)
			}
			// 1) 결정론 검사: 규칙으로 잡히는 것은 판사 없이 먼저 자른다 (싸고, 재현됨)
			for _, re := range c.forbid {
				if regexp.MustCompile(re).MatchString(answer) {
					t.Fatalf("금지 표현 %q 포함: %s", re, answer)
				}
			}
			// 2) LLM 판사: 규칙으로 못 잡는 사실성·톤을 채점
			v, err := JudgeAnswer(ctx, chat, c.question, c.order, answer, 5)
			if err != nil {
				t.Fatal(err)
			}
			if !v.Pass {
				t.Fatalf("판사 실패 %v: %s\n답변: %s", v.Failed, v.Reasons, answer)
			}
		})
	}
}
