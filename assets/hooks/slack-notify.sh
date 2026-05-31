#!/usr/bin/env bash
# carve-slack-notify — Stop: 세션 종료 Slack 알림 (SLACK_WEBHOOK_URL 있을 때만, 비차단).
set -uo pipefail
cat >/dev/null
[ -n "${SLACK_WEBHOOK_URL:-}" ] || exit 0
command -v curl >/dev/null 2>&1 || exit 0
curl -s -X POST -H 'Content-type: application/json' --data '{"text":"[carve] Claude Code 세션 종료"}' "$SLACK_WEBHOOK_URL" >/dev/null 2>&1 || true
exit 0
