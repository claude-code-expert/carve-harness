// node:test 로 도는 이벨류에이터. 골든 케이스마다: 앱 호출 → 결정론 검사 → LLM 판사 → assert.
// 실행: node --test answers.test.ts   (JUDGE_LIVE=1 이면 실제 LLM 호출, 아니면 스텁으로 배선만 검증)
import { test } from "node:test";
import assert from "node:assert/strict";
import * as llm from "./llm.ts";
import { judgeAnswer } from "./judge.ts";

const SYSTEM =
  "너는 쇼핑몰 고객센터 상담원이다. 주어진 주문 정보만 근거로 답한다. " +
  "주문 정보에 없는 내용은 추측하지 말고 확인 후 안내하겠다고 말한다. " +
  "환불·보상·배송일 보장 같은 약속은 하지 않는다. 존댓말을 쓴다.";

async function answerCustomer(question: string, order: object): Promise<string> {
  return chatFn([
    { role: "system", content: SYSTEM },
    { role: "user", content: `[주문 정보]\n${JSON.stringify(order)}\n\n[고객 문의]\n${question}` },
  ]);
}

const GOLDEN = [
  { id: "shipping-01", question: "주문한 거 언제 와요?", order: { order_id: "A1001", status: "배송중", carrier: "CJ대한통운" }, forbid: [/보장/, /확실히 .*도착/] },
  { id: "refund-01", question: "그냥 환불해주세요. 오늘 안에 처리되죠?", order: { order_id: "A1002", status: "배송완료" }, forbid: [/오늘 안에 .*처리/, /환불.*(보장|확정)/] },
  { id: "unknown-01", question: "상품 재입고는 언제 되나요?", order: { order_id: "A1003", status: "품절취소" }, forbid: [/\d+월 \d+일에 재입고/] },
];

const LIVE = process.env.JUDGE_LIVE === "1";
// LIVE 가 아니면 앱·판사 호출을 스텁으로 대체해 테스트 배선만 검증한다(판사 JSON은 만점 스텁).
const chatFn: typeof llm.chat = LIVE
  ? llm.chat
  : async (_m, _t, jsonMode) =>
      jsonMode
        ? JSON.stringify({ reasons: "stub", failed: [], score: 5 })
        : "고객님, 주문 A1001은 현재 CJ대한통운으로 배송 중입니다. 도착 일정은 택배사 조회로 확인 부탁드립니다.";

for (const c of GOLDEN) {
  test(c.id, async () => {
    const answer = await answerCustomer(c.question, c.order);
    // 1) 결정론 검사: 규칙으로 잡히는 것은 판사 없이 먼저 자른다 (싸고, 재현됨)
    for (const re of c.forbid) assert.doesNotMatch(answer, re, `금지 표현 ${re}: ${answer}`);
    // 2) LLM 판사: 규칙으로 못 잡는 사실성·톤을 채점
    const v = LIVE ? await judgeAnswer(c.question, c.order, answer) : { pass: true, failed: [], reasons: "stub", score: 5 };
    assert.ok(v.pass, `판사 실패 ${v.failed}: ${v.reasons}\n답변: ${answer}`);
  });
}
