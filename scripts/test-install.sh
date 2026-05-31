#!/usr/bin/env bash
# test-install.sh — 설치 파이프라인 E2E. 임시 프로젝트에 선택 설치 → doctor → 멱등 → uninstall.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CARVE=(node --disable-warning=ExperimentalWarning "$ROOT/bin/carve.ts")
PASS=0; FAIL=0
ok(){ printf '  \033[32mPASS\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
no(){ printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
printf '{"name":"x","dependencies":{"react":"^19"},"devDependencies":{"typescript":"^5"}}' > "$T/package.json"
echo '{}' > "$T/tsconfig.json"

echo "== 선택 설치 (--only commit,handoff,block-destructive) =="
"${CARVE[@]}" install "$T" --only commit,handoff,block-destructive >/dev/null 2>&1
[ -f "$T/.claude/skills/commit/SKILL.md" ] && ok "선택 스킬(commit) 설치" || no "선택 스킬 설치"
[ -f "$T/.claude/hooks/carve-block-destructive.sh" ] && ok "선택 훅 설치" || no "선택 훅 설치"
[ ! -d "$T/.claude/agents" ] && ok "미선택(에이전트) 미설치 = 과생성 없음" || no "과생성 발생"
[ -f "$T/carve-manifest.json" ] && ok "manifest 생성" || no "manifest 없음"

echo "== doctor =="
"${CARVE[@]}" doctor "$T" 2>/dev/null | grep -q "설치됨" && ok "doctor: 설치됨 보고" || no "doctor"

echo "== 멱등성 (재설치 시 settings 동일) =="
A="$(cat "$T/.claude/settings.json")"
"${CARVE[@]}" install "$T" --only commit,handoff,block-destructive >/dev/null 2>&1
B="$(cat "$T/.claude/settings.json")"
[ "$A" = "$B" ] && ok "재설치 멱등 (훅 중복 없음)" || no "멱등 실패"

echo "== uninstall (클린 제거) =="
"${CARVE[@]}" uninstall "$T" >/dev/null 2>&1
[ ! -f "$T/carve-manifest.json" ] && ok "manifest 제거" || no "manifest 잔존"
[ ! -f "$T/.claude/hooks/carve-block-destructive.sh" ] && ok "훅 제거" || no "훅 잔존"

echo ""; echo "결과: $PASS PASS / $FAIL FAIL"; [ "$FAIL" -eq 0 ]
