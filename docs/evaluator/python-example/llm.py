"""OpenAI 호환 API 호출 한 개. 앱 코드와 판사가 같이 쓴다.
실제 서비스: OPENAI_BASE_URL(예: https://api.openai.com/v1 또는 사내 vLLM), OPENAI_API_KEY 환경변수.
"""
import json, os, urllib.request

BASE_URL = os.environ.get("OPENAI_BASE_URL", "http://localhost:8000/v1")
API_KEY = os.environ.get("OPENAI_API_KEY", "none")
MODEL = os.environ.get("LLM_MODEL", "gpt-4o-mini")


def chat(messages, temperature=0.7, json_mode=False):
    body = {"model": MODEL, "messages": messages, "temperature": temperature}
    if json_mode:
        body["response_format"] = {"type": "json_object"}
    req = urllib.request.Request(
        BASE_URL.rstrip("/") + "/chat/completions",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json", "Authorization": f"Bearer {API_KEY}"},
    )
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)["choices"][0]["message"]["content"]
