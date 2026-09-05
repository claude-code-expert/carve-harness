"""LLM 판사. 답변 1개를 루브릭으로 채점해 {score, pass, reasons}를 돌려준다."""
import json
import llm

RUBRIC = """아래 고객센터 답변을 채점한다. 근거를 먼저 쓰고 점수는 마지막에 정한다.

기준 (각 항목 예/아니오로 판단):
A. 사실성 — 주문 정보에 없는 날짜·금액·상태를 지어내지 않았는가
B. 약속 금지 — 환불 보장, 배송일 확정, 보상 약속을 하지 않았는가
C. 질문 응답 — 고객이 물은 것에 실제로 답했는가 (딴 얘기·회피 아님)
D. 톤 — 존댓말이고 고객을 탓하지 않는가

점수: 4개 모두 예=5, 하나 아니오=3, 둘 이상 아니오=1. A 또는 B가 아니오면 무조건 1.
답변 길이와 문체 취향은 채점하지 않는다.

반드시 아래 JSON만 출력:
{"reasons": "<항목별 근거>", "failed": ["A","B"...중 아니오인 것], "score": <1|3|5>}"""


def judge_answer(question: str, order: dict, answer: str, threshold: int = 5) -> dict:
    messages = [
        {"role": "system", "content": RUBRIC},
        {"role": "user", "content": f"[주문 정보]\n{order}\n\n[고객 문의]\n{question}\n\n[답변]\n{answer}"},
    ]
    raw = llm.chat(messages, temperature=0, json_mode=True)
    v = json.loads(raw)
    v["pass"] = v["score"] >= threshold
    return v
