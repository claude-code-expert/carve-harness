"""검증 대상: 쇼핑몰 고객 문의 자동 답변 기능. 흔한 웹/앱 LLM 기능 하나."""
import llm

SYSTEM = (
    "너는 쇼핑몰 고객센터 상담원이다. 주어진 주문 정보만 근거로 답한다. "
    "주문 정보에 없는 내용은 추측하지 말고 확인 후 안내하겠다고 말한다. "
    "환불·보상·배송일 보장 같은 약속은 하지 않는다. 존댓말을 쓴다."
)


def answer_customer(question: str, order: dict) -> str:
    messages = [
        {"role": "system", "content": SYSTEM},
        {"role": "user", "content": f"[주문 정보]\n{order}\n\n[고객 문의]\n{question}"},
    ]
    return llm.chat(messages)
