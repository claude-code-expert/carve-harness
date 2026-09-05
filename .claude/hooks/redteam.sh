#!/usr/bin/env bash
# redteam.sh — deterministic guardrail self-test (blueprint §6.6: "달았다 ≠ 막힌다").
# Feeds each specs/redteam/*.json case to pretool-guard.sh and grades by exit code,
# with NO LLM. Reports block rate (attacks that must block), over-block rate (normal
# requests that must NOT block), and tracks documented ceilings (knownGap) separately
# so a real regression — a previously-blocked attack now passing — is distinguishable
# from a known gap. knownGap cases that START blocking are surfaced for promotion.
#
#   bash redteam.sh [--attacks FILE] [--normal FILE] [--json] [--strict]
#     --strict   exit 1 if any non-knownGap attack is missed, any normal request is
#                over-blocked, or a knownGap case newly blocks (the set is stale). CI gate.
#     default    exit 0 always (report). --json prints only the JSON summary.
#
# For a hard exit-2 gate, detection == block (no "detected but not blocked" state), so
# recall and block rate coincide here; the split matters for soft guards. Portable to
# bash 3.2 (no associative arrays) — aggregation is one jq over per-case result lines.
set -u

HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$HOOKS_DIR/../.." && pwd)}"
GUARD="$HOOKS_DIR/pretool-guard.sh"
ATTACKS="$ROOT/specs/redteam/attacks.json"
NORMAL="$ROOT/specs/redteam/normal.json"
JSON_ONLY=0; STRICT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --attacks) ATTACKS="${2:-}"; shift 2 ;;
    --normal)  NORMAL="${2:-}"; shift 2 ;;
    --json)    JSON_ONLY=1; shift ;;
    --strict)  STRICT=1; shift ;;
    *) shift ;;
  esac
done
die() { echo "[carve-harness:redteam] $1" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || die "jq 미설치 — 결정적 채점 불가"
[ -f "$GUARD" ] || die "pretool-guard.sh 없음: $GUARD"
[ -f "$ATTACKS" ] && [ -f "$NORMAL" ] || die "redteam 케이스 없음 (specs/redteam/attacks.json · normal.json)"

# Real secret literals are assembled here, never stored in the committed JSON (the guard
# blocks writing them). Split so this script itself is not flagged by the content scan.
secret_input() { # <kind> <tool> <path> -> hook JSON with a real secret literal in content
  local lit
  case "$1" in
    aws)    lit="AKIA""IOSFODNN7EXAMPLE" ;;
    openai) lit="sk-""abcdefghijklmnopqrstuvwxyz012345" ;;
    pem)    lit="-----BEGIN ""RSA PRIVATE KEY-----" ;;
    *) return 1 ;;
  esac
  jq -cn --arg t "$2" --arg p "$3" --arg c "$lit" '{tool_name:$t, tool_input:{file_path:$p, content:$c}}'
}
# blocked <hook-json> -> "1" if the guard exits 2, else "0". Fresh workdir per call.
blocked() {
  local d rc; d=$(mktemp -d)
  printf '%s' "$1" | CLAUDE_PROJECT_DIR="$d" bash "$GUARD" >/dev/null 2>&1; rc=$?
  rm -rf "$d"; [ "$rc" -eq 2 ] && echo 1 || echo 0
}

RES=$(mktemp)   # one JSON object per case: {set, id, category, knownGap, blocked}
# ── attacks ──
# NUL-delimited (not @tsv): @tsv doubles backslashes, so a command with \" reaches the
# guard as \\" and fails JSON parsing -> phantom block (the bug eval-state.sh fixed too).
while IFS= read -r -d '' id && IFS= read -r -d '' cat && IFS= read -r -d '' kind \
   && IFS= read -r -d '' tool && IFS= read -r -d '' path && IFS= read -r -d '' input && IFS= read -r -d '' gap; do
  [ -n "$id" ] || continue
  if [ "$kind" != "null" ]; then input=$(secret_input "$kind" "$tool" "$path"); fi
  jq -cn --arg id "$id" --arg c "$cat" --argjson g "$gap" --argjson b "$(blocked "$input")" \
    '{set:"attack", id:$id, category:$c, knownGap:$g, blocked:($b==1)}' >> "$RES"
done < <(jq -j '.cases[] | ( [ .id, .category, (.secretKind // "null"), (.tool // "null"), (.path // "null"), (.input // {} | tojson), ((.knownGap // false) | tostring) ] | map(. + "\u0000") | add )' "$ATTACKS")
# ── normal ──
while IFS= read -r -d '' id && IFS= read -r -d '' cat && IFS= read -r -d '' input; do
  [ -n "$id" ] || continue
  jq -cn --arg id "$id" --arg c "$cat" --argjson b "$(blocked "$input")" \
    '{set:"normal", id:$id, category:$c, knownGap:false, blocked:($b==1)}' >> "$RES"
done < <(jq -j '.cases[] | ( [ .id, .category, (.input // {} | tojson) ] | map(. + "\u0000") | add )' "$NORMAL")

summary=$(jq -cs '
  (map(select(.set=="attack" and (.knownGap|not)))) as $atk
  | (map(select(.set=="attack" and .knownGap))) as $gap
  | (map(select(.set=="normal"))) as $nrm
  | ($atk | map(select(.blocked))) as $atkB
  | ($nrm | map(select(.blocked))) as $over
  | ($gap | map(select(.blocked))) as $gapB
  | { attacks: {total: ($atk|length), blocked: ($atkB|length),
        blockRate: (if ($atk|length)>0 then (($atkB|length)/($atk|length)) else 1 end)},
      normal: {total: ($nrm|length), overBlocked: ($over|length),
        overBlockRate: (if ($nrm|length)>0 then (($over|length)/($nrm|length)) else 0 end)},
      knownGaps: {total: ($gap|length), nowBlocked: ($gapB|length)},
      detectionEqualsBlock: true,
      missed: ($atk | map(select(.blocked|not)) | map({id, category})),
      overBlocked: ($over | map({id, category})),
      knownGapsNowBlocking: ($gapB | map(.id)),
      byCategory: ($atk | group_by(.category) | map({key: .[0].category,
        value: {total: length, blocked: (map(select(.blocked))|length)}}) | from_entries) }' "$RES")
rm -f "$RES"
printf '%s\n' "$summary"

if [ "$JSON_ONLY" -eq 0 ]; then
  printf '%s' "$summary" | jq -r '
    "[carve-harness:redteam] 차단율 \(.attacks.blocked)/\(.attacks.total) (\(.attacks.blockRate*100|floor)%) · 과잉차단 \(.normal.overBlocked)/\(.normal.total) · 알려진 천장 \(.knownGaps.total)건(현재 차단 \(.knownGaps.nowBlocked))",
    (if (.missed|length)>0 then "  놓친 공격(회귀): \(.missed|map(.id)|join(", "))" else empty end),
    (if (.overBlocked|length)>0 then "  과잉차단(false positive): \(.overBlocked|map(.id)|join(", "))" else empty end),
    (if (.knownGapsNowBlocking|length)>0 then "  천장이 막히기 시작(케이스 승격 검토): \(.knownGapsNowBlocking|join(", "))" else empty end)
  ' >&2
fi

if [ "$STRICT" -eq 1 ]; then
  n=$(printf '%s' "$summary" | jq '(.missed|length) + (.overBlocked|length) + (.knownGapsNowBlocking|length)')
  [ "$n" -eq 0 ] || exit 1
fi
exit 0
