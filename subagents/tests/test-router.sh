#!/bin/bash
# test-router.sh — Squad Router keyword routing test suite
# Usage: bash tests/test-router.sh [--quiet]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/helpers.sh" "$@"

# Verify jq is available
if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required for tests"
  exit 1
fi

echo "Squad Router Test Suite"
echo "======================"

# ─── A. Skip Conditions ──────���──────────────────────────
echo ""
echo "A. Skip Conditions"

assert_no_output "보안 검사해줘" "SQUAD_ROUTER=off"
assert_no_output ""
assert_no_output "/squad-review src/"
assert_no_output "/anything"
assert_no_output "review this code --no-route"
assert_no_output "debug this #direct"
assert_no_output "SECURITY CHECK --NO-ROUTE"
assert_no_output_raw "not valid json at all"
assert_no_output_raw "{}"

# ─── B. Conflict Resolution (Multi-word) ────────────────
echo ""
echo "B. Conflict Resolution (Multi-word patterns)"

# PR review vs PR write
assert_routes_to "pr 리뷰 해줘" "squad-review"
assert_routes_to "please do a pr review" "squad-review"
assert_routes_to "테스트 코드 리뷰 해줘" "squad-review"
assert_routes_to "pr 작성해줘" "squad-gitops"
assert_routes_to "pr 만들어줘" "squad-gitops"
assert_routes_to "pr 써줘" "squad-gitops"

# Security review vs general review
assert_routes_to "보안 리뷰 해줘" "squad-audit"
assert_routes_to "security review please" "squad-audit"
assert_routes_to "보안 검토 부탁" "squad-audit"

# Build error vs build check
assert_routes_to "빌드 에러 수정해줘" "squad-debug"
assert_routes_to "build error fix" "squad-debug"
assert_routes_to "빌드 확인해줘" "squad-qa"
assert_routes_to "빌드 돌려봐" "squad-qa"
assert_routes_to "build check please" "squad-qa"

# Code cleanup
assert_routes_to "코드 정리 해줘" "squad-refactor"
assert_routes_to "do a code cleanup" "squad-refactor"

# ─── C. General Keywords (per agent) ────────────────────
echo ""
echo "C. General Keywords"

# Priority 1: squad-audit
assert_routes_to "보안 점검해줘" "squad-audit"
assert_routes_to "check for security issues" "squad-audit"
assert_routes_to "취약점 분석해" "squad-audit"
assert_routes_to "run an audit" "squad-audit"
assert_routes_to "check for xss" "squad-audit"
assert_routes_to "csrf 방어 확인" "squad-audit"

# Priority 2: squad-debug
assert_routes_to "디버그 해줘" "squad-debug"
assert_routes_to "debug this function" "squad-debug"
assert_routes_to "에러 났어" "squad-debug"
assert_routes_to "there is an exception" "squad-debug"
assert_routes_to "stack trace 분석해" "squad-debug"
assert_routes_to "크래시 원인 찾아줘" "squad-debug"

# Priority 3: squad-plan
assert_routes_to "기획서 작성해줘" "squad-plan"
assert_routes_to "plan the feature" "squad-plan"
assert_routes_to "wireframe 그려줘" "squad-plan"
assert_routes_to "user story 작성" "squad-plan"

# Priority 4: squad-refactor
assert_routes_to "리팩토링 해줘" "squad-refactor"
assert_routes_to "refactor this module" "squad-refactor"
assert_routes_to "extract this function" "squad-refactor"

# Priority 5: squad-docs
assert_routes_to "문서화 해줘" "squad-docs"
assert_routes_to "update the readme" "squad-docs"
assert_routes_to "add jsdoc comments" "squad-docs"

# Priority 6: squad-gitops
assert_routes_to "커밋 메시지 작성해" "squad-gitops"
assert_routes_to "write a commit message" "squad-gitops"
assert_routes_to "generate changelog" "squad-gitops"

# Priority 7: squad-qa
assert_routes_to "테스트 작성해줘" "squad-qa"
assert_routes_to "run the tests" "squad-qa"
assert_routes_to "lint check 해줘" "squad-qa"

# Priority 8: squad-review
assert_routes_to "리뷰 해줘" "squad-review"
assert_routes_to "review my code" "squad-review"
assert_routes_to "diff 봐줘" "squad-review"

# ─── D. Priority Ordering ───────────────────────────────
echo ""
echo "D. Priority Ordering"

assert_routes_to "review the security code" "squad-audit"
assert_routes_to "debug this test failure" "squad-debug"
assert_routes_to "refactor the test helper" "squad-refactor"
assert_routes_to "document the test setup" "squad-docs"

# ─── E. Edge Cases ──────────────────────────────────────
echo ""
echo "E. Edge Cases"

# "plan " requires trailing space — "planet" should NOT match
assert_no_output "planet earth is beautiful"
# But "plan the" should match (contains "plan ")
assert_routes_to "plan the architecture" "squad-plan"
# Case insensitive
assert_routes_to "SECURITY AUDIT NOW" "squad-audit"
# No keywords
assert_no_output "hello how are you"
assert_no_output "deploy to production"
assert_no_output "open the file"
# Long prompt with keyword buried
assert_routes_to "I have this really long description of a problem and somewhere in the middle there is a bug that needs fixing" "squad-debug"

# ─── Summary ────────────────────────────────────────────
summary
