"""pytest로 도는 이벨류에이터. 골든 케이스마다: 앱 호출 → 결정론 검사 → LLM 판사 → assert.
실행: pytest -q   (JUDGE_LIVE=1 이면 실제 LLM 호출, 아니면 스텁으로 배선만 검증)
"""
import json, os, re
import pytest
import app, support_judge as judge, llm

GOLDEN = [
    {
        "id": "shipping-01",
        "question": "주문한 거 언제 와요?",
        "order": {"order_id": "A1001", "status": "배송중", "carrier": "CJ대한통운", "shipped_at": "2026-09-04"},
        "forbid": [r"보장", r"확실히 .*도착"],
    },
    {
        "id": "refund-01",
        "question": "그냥 환불해주세요. 오늘 안에 처리되죠?",
        "order": {"order_id": "A1002", "status": "배송완료", "delivered_at": "2026-09-01"},
        "forbid": [r"오늘 안에 .*처리", r"환불.*(보장|확정)"],
    },
    {
        "id": "unknown-01",
        "question": "상품 재입고는 언제 되나요?",
        "order": {"order_id": "A1003", "status": "품절취소"},
        "forbid": [r"\d+월 \d+일에 재입고"],  # 주문 정보에 없는 날짜를 지어내면 실패
    },
]

LIVE = os.environ.get("JUDGE_LIVE") == "1"


@pytest.fixture(autouse=True)
def stub_llm(monkeypatch):
    """LIVE가 아니면 앱·판사 호출을 스텁으로 대체해 테스트 배선만 검증한다."""
    if LIVE:
        return
    def fake_chat(messages, temperature=0.7, json_mode=False):
        if json_mode:  # 판사 호출
            return json.dumps({"reasons": "stub", "failed": [], "score": 5})
        return "고객님, 주문 A1001은 현재 CJ대한통운으로 배송 중입니다. 도착 일정은 택배사 조회로 확인 부탁드립니다."
    monkeypatch.setattr(llm, "chat", fake_chat)


@pytest.mark.parametrize("case", GOLDEN, ids=[c["id"] for c in GOLDEN])
def test_customer_answer(case):
    answer = app.answer_customer(case["question"], case["order"])

    # 1) 결정론 검사: 규칙으로 잡히는 것은 판사 없이 먼저 자른다 (싸고, 재현됨)
    for pat in case["forbid"]:
        assert not re.search(pat, answer), f"금지 표현 '{pat}' 포함: {answer}"
    assert answer.strip().endswith(("다.", "요.", "니다.", "습니다.")) or LIVE is False

    # 2) LLM 판사: 규칙으로 못 잡는 사실성·톤을 채점
    verdict = judge.judge_answer(case["question"], case["order"], answer)
    assert verdict["pass"], f"판사 실패 {verdict['failed']}: {verdict['reasons']}\n답변: {answer}"
