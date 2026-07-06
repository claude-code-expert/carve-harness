#!/usr/bin/env bash
# Stop: 스택 감지 후 빌드/타입 게이트 (실패 시 exit 2)
fail=0
if [ -f gradlew ]; then ./gradlew compileJava -q 2>&1 | tail -15 || fail=1
elif [ -f backend/gradlew ]; then (cd backend && ./gradlew compileJava -q) 2>&1 | tail -15 || fail=1; fi
if [ -f package.json ]; then pnpm exec tsc --noEmit 2>&1 | tail -15 || fail=1
elif [ -f frontend/package.json ]; then (cd frontend && pnpm exec tsc --noEmit) 2>&1 | tail -15 || fail=1; fi
[ "$fail" -eq 0 ] || { echo "[verify] 검증 실패 — 완료 전 수정 필요" >&2; exit 2; }
exit 0
