#!/usr/bin/env bash
# install.sh — 하네스 설치기. 프로젝트 루트에서 실행 (멱등).
#
# 모드:
#   [fetch]     현재 디렉토리에 하네스가 없으면 → GitHub에서 받아 설치
#               curl -fsSL https://raw.githubusercontent.com/wevesolutions/harness/main/install.sh | bash
#               (사설 레포: GITHUB_TOKEN=... 필요 · 오프라인: HARNESS_SRC_DIR=/path/to/harness)
#   [update]    설치된 하네스를 새 버전으로 패치 — manifest 범위만 갱신
#               curl -fsSL https://raw.githubusercontent.com/wevesolutions/harness/main/install.sh | bash -s -- update
#               VERSION 비교(같으면 no-op) · 변경 파일은 logs/harness-backup/v<이전>/ 백업
#               설치 때 SKIP된 사용자 파일은 건드리지 않음 · 신규 파일은 설치+manifest 추가
#   [rollback]  직전 업데이트 되돌리기 — 네트워크 불필요
#               bash install.sh rollback
#               최신 백업(logs/harness-backup/v<이전>/) 복원 + 버전 스탬프 복귀.
#               백업은 소비된다 — 연속 실행 시 그 이전 백업으로 내려간다.
#   [setup]     대화형 초기 설정 — 설치 후 프로젝트 맞춤 (모든 항목 엔터로 skip)
#               bash install.sh setup
#               git init · PATH · LICENSE 생성 · 보호경로 추가 · 도메인 규칙 ·
#               스택 감지 리포트 · GSD 설치 제안
#   [bootstrap] 하네스 파일이 이미 있으면 → 머신 준비만
#               1) vendor 체크섬 검증  2) .claude/bin 배치(jq·shellcheck)
#               3) jq 없으면 ~/.local/bin/jq  4) 훅 권한 + core.hooksPath
#               5) harness-audit 최종 보고
#
# 환경변수: HARNESS_REPO(기본 wevesolutions/harness) · HARNESS_REF(기본 main)
#           HARNESS_SRC_DIR(로컬 소스 — 네트워크 생략) · HARNESS_FORCE=1(기존 파일 덮어쓰기/재패치)
set -u

HERE="$PWD"
VBIN="$HERE/vendor/bin"
CBIN="$HERE/.claude/bin"
MANIFEST="$HERE/.claude/harness-manifest.txt"
VSTAMP="$HERE/.claude/harness-version"
warn=0
say()  { printf '%s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

MODE="${1:-install}"
case "$MODE" in install|update|rollback|setup) ;; *) fail "알 수 없는 모드: $MODE (install|update|rollback|setup)" ;; esac

# ── [setup] 대화형 초기 설정 ──────────────────────────────────────────────────
# 입력은 /dev/tty (curl|bash에서도 동작). 테스트는 HARNESS_SETUP_STDIN=1 로 stdin 주입.
# tty 없으면 read 실패 → 빈 응답 → 전 항목 skip (행 걸림 없음).
ASK_IN="/dev/tty"
[ "${HARNESS_SETUP_STDIN:-0}" = "1" ] && ASK_IN="/dev/stdin"
ask() { # $1=프롬프트 → $REPLY (입력 불가 시 빈 값)
  printf '%s' "$1"
  IFS= read -r REPLY < "$ASK_IN" 2>/dev/null || REPLY=""
}

run_setup() {
  say "── 대화형 설정 (엔터 = 건너뜀) ──"

  # 1) git 레포
  if ! git -C "$HERE" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    ask "git 레포가 아님 — git init 할까? (pre-commit 게이트에 필요) [y/N] "
    if [ "$REPLY" = "y" ]; then
      git -C "$HERE" init && git -C "$HERE" config core.hooksPath .githooks \
        && say "OK: git init + pre-commit 게이트 활성"
    fi
  fi

  # 2) jq PATH
  if ! command -v jq >/dev/null 2>&1 && [ -f "$HOME/.local/bin/jq" ]; then
    case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *)
      rcfile="$HOME/.$(basename "${SHELL:-bash}")rc"
      ask "~/.local/bin 을 PATH에 추가할까? ($rcfile 에 1줄) [y/N] "
      if [ "$REPLY" = "y" ]; then
        printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$rcfile" \
          && say "OK: $rcfile — 새 셸부터 적용"
      fi
    ;; esac
  fi

  # 3) LICENSE
  if [ ! -e "$HERE/LICENSE" ]; then
    ask "LICENSE 없음 — 생성할까? [1=MIT(내장) 2=Apache-2.0(네트워크) 엔터=skip] "
    case "$REPLY" in
      1)
        yr=$(date +%Y); owner=$(git -C "$HERE" config user.name 2>/dev/null || echo "${USER:-}")
        sed -e "s/{{YEAR}}/$yr/" -e "s/{{OWNER}}/$owner/" \
          "$HERE/vendor/licenses/MIT.txt" > "$HERE/LICENSE" \
          && say "OK: LICENSE (MIT, $owner $yr)" ;;
      2)
        # 법률 텍스트는 전사하지 않는다 — 공식 원문만
        if curl -fsSL https://www.apache.org/licenses/LICENSE-2.0.txt -o "$HERE/LICENSE" 2>/dev/null; then
          say "OK: LICENSE (Apache-2.0)"
        else
          say "WARN: 다운로드 실패(오프라인?) — apache.org/licenses/LICENSE-2.0.txt 수동 저장"
        fi ;;
    esac
  fi

  # 4) 보호 경로 추가 (update-안전: protected-extra.regex는 manifest 밖 → 갱신에도 보존)
  ask "추가 보호 경로 정규식? (예: config/prod/|\\.pem$ — 엔터=skip) "
  if [ -n "$REPLY" ]; then
    printf 'x' | grep -Eq "$REPLY" 2>/dev/null
    if [ $? -le 1 ]; then   # 0=match 1=no-match 2=broken regex
      printf '%s\n' "$REPLY" >> "$HERE/.claude/hooks/protected-extra.regex"
      say "OK: protected-extra.regex 추가 — 가드·pre-commit 즉시 반영, 업데이트에도 보존"
    else
      say "WARN: 잘못된 정규식 — 무시됨"
    fi
  fi

  # 5) 도메인 규칙 (여러 줄, 빈 줄로 종료)
  first=1
  while :; do
    ask "CLAUDE.md 도메인 규칙 1줄? (예: 주문 금액 음수 불가 — 엔터=끝) "
    [ -n "$REPLY" ] || break
    if [ "$first" -eq 1 ] && ! grep -q '^## 도메인 규칙' "$HERE/CLAUDE.md" 2>/dev/null; then
      printf '\n## 도메인 규칙\n' >> "$HERE/CLAUDE.md"
    fi
    printf -- '- %s\n' "$REPLY" >> "$HERE/CLAUDE.md"
    say "OK: 도메인 규칙 추가"
    first=0
  done

  # 6) 스택 감지 리포트 (질문 없음)
  say "── 스택 감지 (Stop 게이트 상태) ──"
  found=0
  if [ -f "$HERE/package.json" ]; then
    found=1
    if [ -x "$HERE/node_modules/.bin/prettier" ] || command -v prettier >/dev/null 2>&1; then
      say "Node: 게이트 활성 (prettier OK)"
    else
      say "Node: prettier 미설치 — 포맷 skip 통과 (npm i -D prettier 권장)"
    fi
  fi
  if [ -f "$HERE/gradlew" ] || [ -f "$HERE/build.gradle" ] || [ -f "$HERE/build.gradle.kts" ]; then
    found=1; say "Java: gradle 게이트 활성"
  fi
  if find "$HERE" -maxdepth 3 -name '*.py' -not -path '*/.git/*' -not -path '*/node_modules/*' 2>/dev/null | grep -q .; then
    found=1
    command -v ruff >/dev/null 2>&1 && say "Python: 게이트 활성 (ruff OK)" \
      || say "Python: ruff 미설치 — 검증 best-effort (pip install ruff pytest 권장)"
  fi
  for ext in go rs rb; do
    if find "$HERE" -maxdepth 3 -name "*.$ext" -not -path '*/.git/*' -not -path '*/node_modules/*' 2>/dev/null | grep -q .; then
      say "미지원 스택 감지(.$ext): Stop 게이트 없음 — README '스택 규칙' 참고"
    fi
  done
  [ "$found" -eq 0 ] && say "지원 스택 미감지 — 코드 추가 시 게이트 자동 동작"

  # 7) GSD (SDD 킷)
  if command -v npx >/dev/null 2>&1; then
    ask "GSD(SDD 킷) 설치? npx get-shit-done-cc --local [y/N] "
    [ "$REPLY" = "y" ] && ( cd "$HERE" && npx get-shit-done-cc --local )
  fi

  say "── 설정 끝. 남은 수동 항목: 팀에 AGENTS.md 정본 공지 · 미지원 스택 게이트 추가 ──"
}

# 설치 대상 목록 — uninstall.sh는 설치 시 기록되는 manifest만 신뢰한다.
HARNESS_PATHS=(
  CLAUDE.md AGENTS.md RULES.md .cursorrules codex.md
  install.sh uninstall.sh
  .claude/CLAUDE.md .claude/settings.json
  .claude/hooks .claude/skills .claude/commands .claude/agents .claude/rules
  .githooks vendor specs/README.md
)

# ── [rollback] ───────────────────────────────────────────────────────────────
if [ "$MODE" = "rollback" ]; then
  [ -f "$MANIFEST" ] || fail "manifest 없음 — 설치된 하네스가 아님. install.sh(설치)를 먼저 실행"
  BAKROOT="$HERE/logs/harness-backup"
  LATEST=$(ls -td "$BAKROOT"/v*/ 2>/dev/null | head -1)
  [ -n "$LATEST" ] || fail "백업 없음 ($BAKROOT/v*/) — 롤백할 업데이트 이력이 없다"
  PREV=$(basename "$LATEST")   # vX.Y.Z = 업데이트 직전 버전
  CURV=$(cat "$VSTAMP" 2>/dev/null | tr -d '[:space:]'); CURV="${CURV:-unknown}"
  say "rollback: v$CURV -> $PREV (복원: logs/harness-backup/$PREV/)"
  # install.sh/uninstall.sh는 tmp+mv로 복원 — 실행 중인 스크립트 truncate 방지
  ( cd "$LATEST" && tar -cf - --exclude=./install.sh --exclude=./uninstall.sh . ) \
    | tar -xf - -C "$HERE" || fail "백업 복원 실패 — $LATEST 확인"
  for f in install.sh uninstall.sh; do
    [ -f "$LATEST/$f" ] || continue
    cp "$LATEST/$f" "$HERE/$f.hnew" && mv "$HERE/$f.hnew" "$HERE/$f"
  done
  printf '%s\n' "${PREV#v}" > "$VSTAMP"
  rm -rf "$LATEST"
  say "OK: v${PREV#v} 복원 완료 — 백업 소비됨 (연속 rollback은 그 이전 백업으로)"
  say "NOTE: 업데이트로 새로 추가된 파일은 남는다(무해) — 필요 시 수동 삭제"
fi

# ── [fetch / update] ─────────────────────────────────────────────────────────
NEED_FETCH=0
if [ "$MODE" = "update" ]; then
  [ -f "$MANIFEST" ] || fail "manifest 없음 — 설치된 하네스가 아님. install.sh(설치)를 먼저 실행"
  NEED_FETCH=1
elif [ "$MODE" = "install" ] && [ ! -f "$HERE/.claude/hooks/pretool-guard.sh" ]; then
  NEED_FETCH=1
fi
if [ "$NEED_FETCH" -eq 1 ]; then
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

  if [ "$MODE" = "update" ]; then
    NEWV=$(cat "$SRC/VERSION" 2>/dev/null | tr -d '[:space:]')
    [ -n "$NEWV" ] || fail "소스에 VERSION 없음 — 업데이트 불가"
    OLDV=$(cat "$VSTAMP" 2>/dev/null | tr -d '[:space:]'); OLDV="${OLDV:-unknown}"
    if [ "$NEWV" = "$OLDV" ] && [ "${HARNESS_FORCE:-0}" != "1" ]; then
      say "이미 최신 버전 (v$OLDV) — 변경 없음"
      exit 0
    fi
    say "update: v$OLDV -> v$NEWV"
    BAK="$HERE/logs/harness-backup/v$OLDV"   # logs/는 gitignore — 백업 소음 없음
    # ponytail: 경로 목록은 실행 중인 스크립트 기준 — 신규 경로까지 받으려면 curl|bash 업데이트가 정본
    for p in "${HARNESS_PATHS[@]}"; do
      [ -e "$SRC/$p" ] || continue
      if grep -qx "$p" "$MANIFEST" 2>/dev/null; then
        diff -rq "$SRC/$p" "$HERE/$p" >/dev/null 2>&1 && continue   # 동일 → 그대로
        mkdir -p "$BAK/$(dirname "$p")"
        cp -R "$HERE/$p" "$BAK/$p" 2>/dev/null
        if [ -d "$SRC/$p" ]; then
          # 오버레이 복사 — 사용자가 디렉토리 안에 추가한 파일은 보존
          mkdir -p "$HERE/$p" && cp -R "$SRC/$p/." "$HERE/$p/"
        else
          # tmp+mv — 실행 중인 install.sh 자기 갱신 안전
          mkdir -p "$HERE/$(dirname "$p")"
          cp "$SRC/$p" "$HERE/$p.hnew" && mv "$HERE/$p.hnew" "$HERE/$p"
        fi
        say "UPDATED: $p (백업: logs/harness-backup/v$OLDV/$p)"
      elif [ ! -e "$HERE/$p" ]; then
        mkdir -p "$HERE/$(dirname "$p")"
        cp -R "$SRC/$p" "$HERE/$p"
        printf '%s\n' "$p" >> "$MANIFEST"
        say "NEW: $p"
      else
        say "SKIP: $p 사용자 파일 (manifest 밖 — 불가침)"
      fi
    done
    printf '%s\n' "$NEWV" > "$VSTAMP"
    say "OK: 버전 스탬프 v$NEWV"
  else
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
    [ -f "$SRC/VERSION" ] && tr -d '[:space:]' < "$SRC/VERSION" > "$VSTAMP"

    # .gitignore — 하네스 런타임 산출물 무시 블록 (마커로 관리, uninstall이 제거)
    if ! grep -q '>>> harness' "$HERE/.gitignore" 2>/dev/null; then
      {
        echo '# >>> harness (managed by install.sh) >>>'
        echo 'logs/'
        echo '.claude/bin/'
        echo '.claude/harness-manifest.txt'
        echo '.claude/harness-version'
        echo 'specs/HANDOFF.md'
        echo '# <<< harness <<<'
      } >> "$HERE/.gitignore"
      say "OK: .gitignore 하네스 블록 추가"
    fi
  fi
fi

# ── [bootstrap] ──────────────────────────────────────────────────────────────
# manifest가 없으면(복사-붙여넣기 설치) 표준 목록으로 생성 — uninstall이 사용.
if [ ! -f "$MANIFEST" ]; then
  mkdir -p "$HERE/.claude"
  printf '%s\n' "${HARNESS_PATHS[@]}" > "$MANIFEST"
fi
# 버전 스탬프가 없으면(복사-붙여넣기 설치·원본 레포) 루트 VERSION에서 생성 — update가 비교에 사용.
if [ ! -f "$VSTAMP" ] && [ -f "$HERE/VERSION" ]; then
  tr -d '[:space:]' < "$HERE/VERSION" > "$VSTAMP"
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

# (4.5) interactive project setup.
[ "$MODE" = "setup" ] && run_setup

# (5) final state report.
say "---"
if CLAUDE_PROJECT_DIR="$HERE" bash "$HERE/.claude/hooks/harness-audit.sh"; then
  say "---"
  [ "$warn" -eq 0 ] && say "설치 완료 — 하네스 전 게이트 활성." \
                    || say "설치 완료(경고 있음) — 위 WARN/ACTION/SKIP 항목 확인."
  if [ "$MODE" = "install" ]; then
    say "다음 단계: bash install.sh setup — 대화형 초기 설정 (git·PATH·LICENSE·보호경로·도메인 규칙·GSD)"
  fi
else
  say "---"
  say "설치됐으나 audit FAIL 항목 존재 — 위 FAIL 라인 해결 후 재실행."
  exit 1
fi
