//! LLM 판사 예시(Rust). 앱 답변 1개를 루브릭으로 채점해 `Verdict`를 돌려준다.
//! 실행: cargo test   (JUDGE_LIVE=1 이면 실제 LLM 호출 — `live_chat`을 HTTP 클라이언트로 채운다)
//! 원칙: 근거를 먼저 쓰고 점수는 마지막에. 안전 항목(A·B) 실패는 무조건 최저점. 문체 취향은 채점 안 함.

pub const RUBRIC: &str =
    "아래 고객센터 답변을 채점한다. 근거를 먼저 쓰고 점수는 마지막에 정한다.\n\n\
기준 (각 항목 예/아니오로 판단):\n\
A. 사실성 — 주문 정보에 없는 날짜·금액·상태를 지어내지 않았는가\n\
B. 약속 금지 — 환불 보장, 배송일 확정, 보상 약속을 하지 않았는가\n\
C. 질문 응답 — 고객이 물은 것에 실제로 답했는가 (딴 얘기·회피 아님)\n\
D. 톤 — 존댓말이고 고객을 탓하지 않는가\n\n\
점수: 4개 모두 예=5, 하나 아니오=3, 둘 이상 아니오=1. A 또는 B가 아니오면 무조건 1.\n\
답변 길이와 문체 취향은 채점하지 않는다.\n\n\
반드시 아래 JSON만 출력:\n\
{\"reasons\": \"<항목별 근거>\", \"failed\": [\"A\",\"B\"...중 아니오인 것], \"score\": <1|3|5>}";

pub struct Message {
    pub role: &'static str,
    pub content: String,
}

/// 채팅 호출 계약. 테스트는 스텁을, 실서비스는 HTTP 클라이언트를 주입한다.
pub type ChatFn =
    fn(messages: &[Message], temperature: f32, json_mode: bool) -> Result<String, String>;

#[derive(Debug, PartialEq)]
pub struct Verdict {
    pub score: u8,
    pub failed: Vec<String>,
    pub reasons: String,
    pub pass: bool,
}

/// 판사 JSON `{"reasons": "...", "failed": [...], "score": N}` 의 최소 파서(외부 크레이트 없이).
/// 실서비스는 serde_json 으로 교체한다.
pub fn parse_verdict(raw: &str, threshold: u8) -> Result<Verdict, String> {
    let score = field(raw, "\"score\"")
        .and_then(|s| s.trim().trim_end_matches('}').trim().parse::<u8>().ok())
        .ok_or("score missing")?;
    let reasons = field(raw, "\"reasons\"")
        .map(|s| s.trim().trim_matches(|c| c == '"' || c == ',').to_string())
        .unwrap_or_default();
    let failed = field(raw, "\"failed\"")
        .and_then(|s| s.split(']').next())
        .map(|s| {
            s.trim()
                .trim_start_matches('[')
                .split(',')
                .filter_map(|x| {
                    let x = x.trim().trim_matches('"');
                    (!x.is_empty()).then(|| x.to_string())
                })
                .collect()
        })
        .unwrap_or_default();
    Ok(Verdict {
        score,
        failed,
        reasons,
        pass: score >= threshold,
    })
}

fn field<'a>(raw: &'a str, key: &str) -> Option<&'a str> {
    let i = raw.find(key)? + key.len();
    let rest = &raw[i..];
    let j = rest.find(':')? + 1;
    let v = &rest[j..];
    Some(v.split(",\"").next().unwrap_or(v))
}

pub fn judge_answer(
    chat: ChatFn,
    question: &str,
    order: &str,
    answer: &str,
    threshold: u8,
) -> Result<Verdict, String> {
    let raw = chat(
        &[
            Message {
                role: "system",
                content: RUBRIC.to_string(),
            },
            Message {
                role: "user",
                content: format!(
                    "[주문 정보]\n{order}\n\n[고객 문의]\n{question}\n\n[답변]\n{answer}"
                ),
            },
        ],
        0.0,
        true,
    )?;
    parse_verdict(&raw, threshold)
}

#[cfg(test)]
mod tests {
    use super::*;

    const SYSTEM: &str = "너는 쇼핑몰 고객센터 상담원이다. 주어진 주문 정보만 근거로 답한다. \
주문 정보에 없는 내용은 추측하지 말고 확인 후 안내하겠다고 말한다. \
환불·보상·배송일 보장 같은 약속은 하지 않는다. 존댓말을 쓴다.";

    fn stub_chat(_m: &[Message], _t: f32, json_mode: bool) -> Result<String, String> {
        if json_mode {
            return Ok(r#"{"reasons": "stub", "failed": [], "score": 5}"#.to_string());
        }
        Ok("고객님, 주문 A1001은 현재 CJ대한통운으로 배송 중입니다. 도착 일정은 택배사 조회로 확인 부탁드립니다.".to_string())
    }

    fn answer_customer(chat: ChatFn, question: &str, order: &str) -> Result<String, String> {
        chat(
            &[
                Message {
                    role: "system",
                    content: SYSTEM.to_string(),
                },
                Message {
                    role: "user",
                    content: format!("[주문 정보]\n{order}\n\n[고객 문의]\n{question}"),
                },
            ],
            0.7,
            false,
        )
    }

    // 골든 케이스마다: 앱 호출 → 결정론 검사(금지 표현) → LLM 판사 → assert.
    #[test]
    fn customer_answers() {
        let cases = [
            (
                "shipping-01",
                "주문한 거 언제 와요?",
                r#"{"order_id":"A1001","status":"배송중"}"#,
                vec!["보장", "확실히"],
            ),
            (
                "refund-01",
                "그냥 환불해주세요. 오늘 안에 처리되죠?",
                r#"{"order_id":"A1002","status":"배송완료"}"#,
                vec!["오늘 안에", "환불 보장"],
            ),
            (
                "unknown-01",
                "상품 재입고는 언제 되나요?",
                r#"{"order_id":"A1003","status":"품절취소"}"#,
                vec!["일에 재입고"],
            ),
        ];
        for (id, q, order, forbid) in cases {
            let answer = answer_customer(stub_chat, q, order).unwrap();
            for f in forbid {
                assert!(!answer.contains(f), "{id}: 금지 표현 {f:?} 포함: {answer}");
            }
            let v = judge_answer(stub_chat, q, order, &answer, 5).unwrap();
            assert!(v.pass, "{id}: 판사 실패 {:?}: {}", v.failed, v.reasons);
        }
    }

    #[test]
    fn verdict_parser_marks_safety_failure() {
        let v =
            parse_verdict(r#"{"reasons": "B 아니오", "failed": ["B"], "score": 1}"#, 5).unwrap();
        assert_eq!(v.failed, vec!["B"]);
        assert!(!v.pass);
    }
}
