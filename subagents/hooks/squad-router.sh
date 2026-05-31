#!/bin/bash
# squad-router.sh — Keyword-based subagent routing hook
# Triggered by UserPromptSubmit: detects keywords in user prompts
# and injects subagent delegation context via stdout.
#
# Registered automatically by install.sh
# See docs/SQUAD-ROUTER-KEYWORDS.md for keyword reference
#
# Opt-out:
#   Per-prompt: add --no-route or #direct to your prompt
#   Global:     export SQUAD_ROUTER=off
set -euo pipefail

# --- Env-level kill switch ---
if [ "${SQUAD_ROUTER:-}" = "off" ]; then
  exit 0
fi

# --- Read stdin (JSON from Claude Code) ---
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT
cat > "$TMPFILE"

# --- jq guard ---
if ! command -v jq &>/dev/null; then exit 0; fi
if ! jq empty < "$TMPFILE" 2>/dev/null; then exit 0; fi

PROMPT=$(jq -r '.prompt // ""' < "$TMPFILE")
if [ -z "$PROMPT" ]; then exit 0; fi

# --- Normalize to lowercase ---
LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')

# === Phase 1: SKIP conditions ===

# Skip slash commands (user already chose explicitly)
case "$LOWER" in
  "/"*) exit 0 ;;
esac

# Skip opt-out markers
case "$LOWER" in
  *"--no-route"*|*"#direct"*) exit 0 ;;
esac

# === Phase 2: CONFLICT resolution (multi-word patterns first) ===
AGENT=""
case "$LOWER" in
  *"pr 리뷰"*|*"pr review"*|*"테스트 코드 리뷰"*)
    AGENT="squad-review" ;;
  *"pr 작성"*|*"pr 만들"*|*"pr 써"*)
    AGENT="squad-gitops" ;;
  *"보안 리뷰"*|*"보안 검토"*|*"security review"*)
    AGENT="squad-audit" ;;
  *"에러 테스트"*|*"빌드 에러"*|*"build error"*)
    AGENT="squad-debug" ;;
  *"빌드 확인"*|*"빌드 돌"*|*"build check"*)
    AGENT="squad-qa" ;;
  *"코드 정리"*|*"code cleanup"*)
    AGENT="squad-refactor" ;;
esac

# === Phase 3: GENERAL keyword matching (priority order) ===
if [ -z "$AGENT" ]; then
  case "$LOWER" in
    # 1. squad-audit (security — highest priority)
    *"보안"*|*"security"*|*"취약점"*|*"vulnerab"*|*"audit"*|*"owasp"*|\
    *"시크릿"*|*"secret"*|*"인젝션"*|*"injection"*|*"xss"*|*"csrf"*)
      AGENT="squad-audit" ;;

    # 2. squad-debug (error/bug)
    *"디버그"*|*"debug"*|*"에러"*|*"error"*|*"버그"*|*"bug"*|\
    *"오류"*|*"크래시"*|*"crash"*|*"stack trace"*|*"traceback"*|*"exception"*)
      AGENT="squad-debug" ;;

    # 3. squad-plan (planning)
    *"기획"*|*"plan "*|*"설계해"*|*"와이어프레임"*|*"wireframe"*|\
    *"유저스토리"*|*"user story"*|*"브레인스토밍"*|*"brainstorm"*|\
    *"스펙"*|*"spec"*|*"요구사항"*|*"구현 계획"*)
      AGENT="squad-plan" ;;

    # 4. squad-refactor (refactoring)
    *"리팩토링"*|*"리팩터"*|*"refactor"*|*"클린업"*|*"cleanup"*|*"clean up"*|\
    *"추출"*|*"extract"*|*"중복 제거"*|*"코드 개선"*|*"함수 분리"*|*"컴포넌트 분리"*)
      AGENT="squad-refactor" ;;

    # 5. squad-docs (documentation)
    *"문서화"*|*"문서"*|*"document"*|*"readme"*|*"리드미"*|\
    *"jsdoc"*|*"tsdoc"*|*"주석"*|*"comment"*)
      AGENT="squad-docs" ;;

    # 6. squad-gitops (git operations)
    *"커밋"*|*"commit"*|*"체인지로그"*|*"changelog"*|\
    *"릴리즈 노트"*|*"release note"*|*"conventional"*)
      AGENT="squad-gitops" ;;

    # 7. squad-qa (test/verification)
    *"테스트"*|*"test"*|*"qa"*|*"검증"*|\
    *"린트"*|*"lint"*|*"타입체크"*|*"type check"*|*"리그레션"*|*"regression"*)
      AGENT="squad-qa" ;;

    # 8. squad-review (broadest — last)
    *"리뷰"*|*"review"*|*"코드 검토"*|*"검토해"*|*"diff 봐"*)
      AGENT="squad-review" ;;
  esac
fi

if [ -z "$AGENT" ]; then
  exit 0
fi

# === Output: inject context via hookSpecificOutput ===
CONTEXT="[Squad Router] IMPORTANT: You MUST delegate this task to the ${AGENT} subagent. Do NOT handle it directly in the main session. Invoke: Agent(subagent_type=\"${AGENT}\", prompt=\"<user's full request>\"). This is a hard requirement from the user's installed hook system."

jq -n \
  --arg ctx "$CONTEXT" \
  '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":$ctx}}'

exit 0
