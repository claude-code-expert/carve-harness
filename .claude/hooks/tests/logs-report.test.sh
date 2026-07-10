#!/usr/bin/env bash
# Assertions for logs-report.sh (Dev-4): summary counts and --rotate deletion.
# Uses a temp CLAUDE_PROJECT_DIR — never touches live logs/.

HOOK="$(dirname "$0")/../logs-report.sh"
fail=0; pass=0
ok() { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
no() { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }

tmp=$(mktemp -d); mkdir -p "$tmp/logs"
printf '{"ts":"2026-07-08T01:00:00Z","event":"PreToolUse","tool":"Write","decision":"block","target":"<masked>"}\n' > "$tmp/logs/a.jsonl"
printf '{"ts":"2026-07-08T02:00:00Z","event":"PreToolUse","tool":"Bash","decision":"allow"}\n' >> "$tmp/logs/a.jsonl"

# (1) summary reports the block line with tool+target.
out=$(CLAUDE_PROJECT_DIR="$tmp" bash "$HOOK" 7)
printf '%s' "$out" | grep -q 'Write  <masked>' && ok "summary lists blocked tool/target" || no "summary block line ($out)"

# (2) summary counts event x decision.
printf '%s' "$out" | grep -Eq '1 PreToolUse block' && ok "summary counts event x decision" || no "summary counts"

# (3) --rotate deletes only files older than keep-days.
# BSD touch has no -d '30 days ago' — compute the stamp (BSD -v / GNU -d)
old="$tmp/logs/old.jsonl"; printf '{}\n' > "$old"
touch -t "$(date -v-30d +%Y%m%d%H%M 2>/dev/null || date -d '30 days ago' +%Y%m%d%H%M)" "$old"
CLAUDE_PROJECT_DIR="$tmp" bash "$HOOK" --rotate 7 >/dev/null 2>&1
if [ ! -f "$old" ] && [ -f "$tmp/logs/a.jsonl" ]; then
  ok "--rotate deletes old, keeps recent"
else
  no "--rotate selection"
fi

# (4) non-numeric args rejected.
CLAUDE_PROJECT_DIR="$tmp" bash "$HOOK" --rotate x >/dev/null 2>&1
[ $? -ne 0 ] && ok "--rotate non-numeric rejected" || no "--rotate validation"

rm -rf "$tmp"
printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
