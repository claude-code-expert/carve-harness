#!/usr/bin/env bash
# eval-trend.sh — deterministic reader/appender for the golden-set score trend
# (specs/eval-score.json). The carve-eval workflow used to let an LLM agent read
# and rewrite this file; that lost a run and mis-tagged versions. Now the agent
# only relays JSON — this script owns ordinal, version and append-only integrity.
#
#   bash eval-trend.sh read   [--file PATH]
#       stdout: {"runs":N,"lastSuiteScore":X|null,"version":"<VERSION>"|null,
#                "lastCaseVersions":[{"id","caseVersion","caseScore"}]}
#       Missing/empty file -> runs 0. Unusable JSON -> exit 1 (fail-closed).
#   bash eval-trend.sh append ENTRY.json [--file PATH]
#       Appends ENTRY as the next run. Enforces:
#         - run       = existing count + 1  (caller's value is ignored)
#         - version   = repo VERSION file   (caller's value is ignored)
#         - prevHash  = sha256 of the canonical prior .runs — and BEFORE appending, the
#                       last run's stored prevHash must match the runs that precede it.
#                       Any edit to an earlier run -> exit 1 "trend tampered". Human
#                       corrections are done by hand and recorded in DECISIONS.md.
#       Existing runs never change. Atomic write (tmp + mv).
set -o pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
CMD="${1:-}"; shift 2>/dev/null || true
ENTRY=""; FILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --file) FILE="${2:-}"; shift 2 ;;
    *) [ -z "$ENTRY" ] && ENTRY="$1"; shift ;;
  esac
done
[ -n "$FILE" ] || FILE="$ROOT/specs/eval-score.json"

die() { echo "[carve-harness:eval-trend] $1" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || die "jq 미설치 — 추이 파일을 다룰 수 없다(fail-closed)"

sha() { # stdin -> hex
  if command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'
  else shasum -a 256 | awk '{print $1}'; fi
}
canon_runs_hash() { jq -cS '.runs' "$1" | sha; }   # canonical (sorted keys, compact)

version_now() { tr -d '[:space:]' < "$ROOT/VERSION" 2>/dev/null; }

case "$CMD" in
  read)
    if [ ! -s "$FILE" ]; then
      jq -cn --arg v "$(version_now)" '{runs:0, lastSuiteScore:null, version:(if $v=="" then null else $v end), lastCaseVersions:[]}'
      exit 0
    fi
    jq -e '.runs | type == "array"' "$FILE" >/dev/null 2>&1 || die "추이 파일 파싱 실패 또는 .runs 없음: $FILE"
    jq -c --arg v "$(version_now)" '
      { runs: (.runs | length),
        lastSuiteScore: (.runs[-1].suiteScore // null),
        version: (if $v == "" then null else $v end),
        lastCaseVersions: [ (.runs[-1].cases // [])[] | {id, caseVersion: (.caseVersion // null), caseScore: (.caseScore // null)} ] }' "$FILE"
    ;;
  append)
    [ -n "$ENTRY" ] && [ -f "$ENTRY" ] || die "usage: eval-trend.sh append ENTRY.json [--file PATH]"
    jq -e 'type == "object" and (.cases | type == "array") and has("suiteScore")' "$ENTRY" >/dev/null 2>&1 \
      || die "엔트리 형식 오류 — object with suiteScore and cases[] 필요: $ENTRY"
    if [ -s "$FILE" ]; then
      jq -e '.runs | type == "array"' "$FILE" >/dev/null 2>&1 || die "추이 파일 파싱 실패: $FILE — 손상된 추이에 append 하지 않는다"
      # Integrity: the last run carries the hash of everything before it.
      stored=$(jq -r '.runs[-1].prevHash // empty' "$FILE")
      if [ -n "$stored" ]; then
        expect=$(jq -cS '.runs[:-1]' "$FILE" | sha)
        [ "$stored" = "$expect" ] || die "trend tampered — 마지막 run 이전 기록이 변조됐다(prevHash 불일치). 사람이 고친 거면 DECISIONS.md에 기록하고 --file 로 새 추이를 시작하라"
      fi
      n=$(jq '.runs | length' "$FILE")
      prev=$(canon_runs_hash "$FILE")
    else
      mkdir -p "$(dirname "$FILE")"
      printf '{"runs":[]}\n' > "$FILE"
      n=0; prev=$(canon_runs_hash "$FILE")
    fi
    v=$(version_now)
    tmp=$(mktemp)
    if jq --slurpfile e "$ENTRY" --argjson run "$((n + 1))" --arg v "$v" --arg h "$prev" \
         '.runs += [ $e[0] + {run: $run, version: (if $v == "" then null else $v end), prevHash: $h} ]' \
         "$FILE" > "$tmp" 2>/dev/null && jq -e '.runs | length == '"$((n + 1))" "$tmp" >/dev/null 2>&1; then
      mv "$tmp" "$FILE"
    else
      rm -f "$tmp"; die "append 실패 — 파일 미변경"
    fi
    jq -c '.runs[-1] | {run, version, suiteScore, cases: (.cases | length)}' "$FILE"
    ;;
  *) die "usage: eval-trend.sh read|append ENTRY.json [--file PATH]" ;;
esac
