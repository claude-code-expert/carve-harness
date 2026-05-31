#!/usr/bin/env bash
# test-squad.sh — Squad 라우터 단위 테스트. 키워드 → 위임 에이전트 / 비트리거 무반응.
# 라우터는 jq 의존 — 없으면 SKIP.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
R="$ROOT/assets/squad/hooks/squad-router.sh"
PASS=0; FAIL=0
ok(){ printf '  \033[32mPASS\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
no(){ printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }

if ! command -v jq >/dev/null 2>&1; then
  echo "  SKIP — jq가 없어 squad-router를 측정할 수 없음 (brew install jq)"; exit 0
fi

# route <name> <prompt> <expected-agent>
route(){
  local name="$1" prompt="$2" exp="$3" got
  got=$(printf '{"prompt":"%s"}' "$prompt" | bash "$R" | grep -o 'squad-[a-z]*' | head -1)
  if [ "$got" = "$exp" ]; then ok "$name → $got"; else no "$name → ${got:-(없음)}, 기대 $exp"; fi
}

echo "== 키워드 라우팅 =="
route "코드 리뷰"   "이거 코드 리뷰 해줘"   squad-review
route "테스트"      "테스트 돌려줘"         squad-qa
route "디버그"      "이 에러 디버그 해줘"   squad-debug
route "보안"        "보안 취약점 점검"      squad-audit
route "리팩토링"    "리팩토링 해줘"         squad-refactor
route "기획"        "기능 기획 도와줘"      squad-plan
route "문서화"      "문서화 해줘"           squad-docs
route "커밋"        "커밋 메시지 작성"      squad-gitops

echo "== 오발화 (비트리거는 무반응) =="
for p in "안녕하세요" "오늘 점심 뭐 먹지" "그냥 설명만 해줘"; do
  got=$(printf '{"prompt":"%s"}' "$p" | bash "$R" | grep -o 'squad-[a-z]*' | head -1)
  if [ -z "$got" ]; then ok "무반응: $p"; else no "오발화: $p → $got"; fi
done

echo ""; echo "결과: $PASS PASS / $FAIL FAIL"; [ "$FAIL" -eq 0 ]
