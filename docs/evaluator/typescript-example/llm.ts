// OpenAI 호환 API 호출 한 개. 앱 코드와 판사가 같이 쓴다.
// 실제 서비스: OPENAI_BASE_URL(예: https://api.openai.com/v1 또는 사내 vLLM), OPENAI_API_KEY 환경변수.
// 외부 패키지 없음 — Node 22+ 내장 fetch. 실행: node --test answers.test.ts (Node >= 22.18 타입 스트리핑)
export type Message = { role: "system" | "user" | "assistant"; content: string };

const BASE_URL = process.env.OPENAI_BASE_URL ?? "http://localhost:8000/v1";
const API_KEY = process.env.OPENAI_API_KEY ?? "none";
const MODEL = process.env.LLM_MODEL ?? "gpt-4o-mini";

export async function chat(messages: Message[], temperature = 0.7, jsonMode = false): Promise<string> {
  const body: Record<string, unknown> = { model: MODEL, messages, temperature };
  if (jsonMode) body.response_format = { type: "json_object" };
  const r = await fetch(`${BASE_URL.replace(/\/$/, "")}/chat/completions`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${API_KEY}` },
    body: JSON.stringify(body),
  });
  if (!r.ok) throw new Error(`llm ${r.status}`);
  const data = (await r.json()) as { choices: { message: { content: string } }[] };
  return data.choices[0].message.content;
}
