#!/usr/bin/env bash
# install.sh — 하네스 설치기. 프로젝트 루트에서 실행 (멱등).
#
# 두 모드 자동 판별:
#   [fetch]     현재 디렉토리에 하네스가 없으면 → GitHub에서 받아 설치
#               curl -fsSL https://raw.githubusercontent.com/wevesolutions/harness/main/install.sh | bash
#               (사설 레포: GITHUB_TOKEN=... 필요 · 오프라인: HARNESS_SRC_DIR=/path/to/harness)
#   [bootstrap] 하네스 파일이 이미 있으면 → 머신 준비만
#               1) vendor 체크섬 검증  2) .claude/bin 배치(jq·shellcheck)
#               3) jq 없으면 ~/.local/bin/jq  4) 훅 권한 + core.hooksPath
#               5) harness-audit 최종 보고
#
# 환경변수: HARNESS_REPO(기본 wevesolutions/harness) · HARNESS_REF(기본 main)
#           HARNESS_SRC_DIR(로컬 소스 — 네트워크 생략) · HARNESS_FORCE=1(기존 파일 덮어쓰기)
set -u

HERE="$PWD"
VBIN="$HERE/vendor/bin"
CBIN="$HERE/.claude/bin"
MANIFEST="$HERE/.claude/harness-manifest.txt"
warn=0
say()  { printf '%s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

# 설치 대상 목록 — uninstall.sh는 설치 시 기록되는 manifest만 신뢰한다.
HARNESS_PATHS=(
  CLAUDE.md AGENTS.md RULES.md .cursorrules codex.md
  install.sh uninstall.sh
  .claude/CLAUDE.md .claude/settings.json
  .claude/hooks .claude/skills .claude/commands .claude/agents .claude/rules
  .githooks vendor specs/README.md
)

# ── [fetch] ──────────────────────────────────────────────────────────────────
if [ ! -f "$HERE/.claude/hooks/pretool-guard.sh" ]; then
  SRC="${HARNESS_SRC_DIR:-}"
  TMPD=""
  if [ -z "$SRC" ]; then
    command -v curl >/dev/null 2>&1 || fail "curl 없음 — 오프라인이면 HARNESS_SRC_DIR=/복사된/하네스 로 실행"
    command -v tar  >/dev/null 2>&1 || fail "tar 없음"
    REPO="${HARNESS_REPO:-wevesolutions/harness}"
    REF="${HARNESS_REF:-main}"
    TMPD=$(mktemp -d)
    trap '[ -n "$TMPD" ] && rm -rf "$TMPD"' EXIT
    say "fetch: https://github.com/$REPO @ $REF"
    if [ -n "${GITHUB_TOKEN:-}" ]; then
      curl -fsSL -H "Authorization: token $GITHUB_TOKEN" \
        "https://codeload.github.com/$REPO/tar.gz/$REF" | tar -xz -C "$TMPD" --strip-components=1 \
        || fail "다운로드 실패 — 레포/브랜치/토큰 확인"
    else
      curl -fsSL "https://codeload.github.com/$REPO/tar.gz/$REF" | tar -xz -C "$TMPD" --strip-components=1 \
        || fail "다운로드 실패 — 사설 레포면 GITHUB_TOKEN 필요"
    fi
    SRC="$TMPD"
  fi
  [ -f "$SRC/.claude/hooks/pretool-guard.sh" ] || fail "소스에 하네스 없음: $SRC"

  mkdir -p "$HERE/.claude"   # 나머지 경로는 복사 루프가 생성 — 미리 만들면 SKIP 오탐
  : > "$MANIFEST"
  for p in "${HARNESS_PATHS[@]}"; do
    [ -e "$SRC/$p" ] || continue
    if [ -e "$HERE/$p" ] && [ "${HARNESS_FORCE:-0}" != "1" ]; then
      say "SKIP: $p 이미 존재 (덮어쓰려면 HARNESS_FORCE=1)"
      warn=1
      continue
    fi
    mkdir -p "$HERE/$(dirname "$p")"
    cp -R "$SRC/$p" "$HERE/$p"
    printf '%s\n' "$p" >> "$MANIFEST"
    say "OK: $p"
  done

  # .gitignore — 하네스 런타임 산출물 무시 블록 (마커로 관리, uninstall이 제거)
  if ! grep -q '>>> harness' "$HERE/.gitignore" 2>/dev/null; then
    {
      echo '# >>> harness (managed by install.sh) >>>'
      echo 'logs/'
      echo '.claude/bin/'
      echo '.claude/harness-manifest.txt'
      echo 'specs/HANDOFF.md'
      echo '# <<< harness <<<'
    } >> "$HERE/.gitignore"
    say "OK: .gitignore 하네스 블록 추가"
  fi
fi

# ── [bootstrap] ──────────────────────────────────────────────────────────────
# manifest가 없으면(복사-붙여넣기 설치) 표준 목록으로 생성 — uninstall이 사용.
if [ ! -f "$MANIFEST" ]; then
  mkdir -p "$HERE/.claude"
  printf '%s\n' "${HARNESS_PATHS[@]}" > "$MANIFEST"
fi

# (1) vendor integrity — tampered/corrupt binaries must never be installed.
if [ -f "$VBIN/SHA256SUMS" ]; then
  ( cd "$VBIN" && sha256sum -c SHA256SUMS >/dev/null 2>&1 ) \
    || fail "vendor/bin 체크섬 불일치 — 손상/변조 의심, 설치 중단"
  say "OK: vendor 바이너리 체크섬 검증"
else
  say "WARN: vendor/bin/SHA256SUMS 없음 — 내장 바이너리 설치 생략 (온라인 환경 전제)"
  warn=1
fi

# (2) repo-local binaries (.claude/bin) — logs-report·stop-verify가 참조.
arch=$(uname -m)
case "$arch" in
  x86_64)         JQ_SRC="$VBIN/jq-linux-amd64" ;;
  aarch64|arm64)  JQ_SRC="$VBIN/jq-linux-arm64" ;;
  *)              JQ_SRC="" ;;
esac
mkdir -p "$CBIN"
if [ -n "$JQ_SRC" ] && [ -f "$JQ_SRC" ]; then
  cp "$JQ_SRC" "$CBIN/jq" && chmod +x "$CBIN/jq"
  say "OK: .claude/bin/jq ($arch)"
elif [ -f "$VBIN/SHA256SUMS" ]; then
  say "WARN: $arch 용 내장 jq 없음"
  warn=1
fi
if [ "$arch" = "x86_64" ] && [ -f "$VBIN/shellcheck-linux-x86_64" ]; then
  cp "$VBIN/shellcheck-linux-x86_64" "$CBIN/shellcheck" && chmod +x "$CBIN/shellcheck"
  say "OK: .claude/bin/shellcheck"
fi

# (3) machine-level jq — Claude Code 훅은 사용자 PATH에서 jq를 찾는다.
if command -v jq >/dev/null 2>&1; then
  say "OK: jq 이미 PATH에 있음 ($(command -v jq))"
elif [ -f "$CBIN/jq" ]; then
  mkdir -p "$HOME/.local/bin"
  cp "$CBIN/jq" "$HOME/.local/bin/jq" && chmod +x "$HOME/.local/bin/jq"
  say "OK: jq -> ~/.local/bin/jq 설치"
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) say "ACTION: ~/.local/bin 이 PATH에 없음 — 셸 rc에 추가 필요:"
       say '  export PATH="$HOME/.local/bin:$PATH"'
       warn=1 ;;
  esac
else
  fail "jq 없음 + 내장본도 없음 — 훅이 fail-closed로 모든 쓰기를 차단한다. jq 확보 필수"
fi

# (4) permissions + agent-agnostic commit gate.
chmod +x "$HERE"/.claude/hooks/*.sh "$HERE"/.githooks/pre-commit 2>/dev/null
say "OK: 훅 실행 권한"
if git -C "$HERE" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git -C "$HERE" config core.hooksPath .githooks
  say "OK: git core.hooksPath=.githooks (pre-commit 게이트 활성)"
else
  say "WARN: git 레포 아님 — 커밋 게이트 비활성. git init 후 재실행 권장"
  warn=1
fi

# (5) final state report.
say "---"
if CLAUDE_PROJECT_DIR="$HERE" bash "$HERE/.claude/hooks/harness-audit.sh"; then
  say "---"
  [ "$warn" -eq 0 ] && say "설치 완료 — 하네스 전 게이트 활성." \
                    || say "설치 완료(경고 있음) — 위 WARN/ACTION/SKIP 항목 확인."
else
  say "---"
  say "설치됐으나 audit FAIL 항목 존재 — 위 FAIL 라인 해결 후 재실행."
  exit 1
fi
