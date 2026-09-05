#!/usr/bin/env bash
# install.sh — 하네스 설치기. 프로젝트 루트에서 실행 (멱등).
#
# 모드:
#   [fetch]     현재 디렉토리에 하네스가 없으면 → GitHub에서 받아 설치
#               curl -fsSL https://raw.githubusercontent.com/claude-code-expert/carve-harness/main/install.sh | bash
#               (오프라인: HARNESS_SRC_DIR=/path/to/harness)
#               설치 전 전체 항목 체크박스 목록 표시 (섹션: 필수md·훅·스킬·커맨드·오케스트레이터)
#               ↑↓/jk 이동 · 스페이스 토글(섹션 행=하위 일괄) · 1-5 섹션 점프 · a 전체 · 엔터 설치
#               기본 전체 선택 — 엔터만 치면 전체 설치
#               설치 시작 시 '맞춤 구축(권장)/수동 선택' 질문 — 맞춤은 전체 설치 후
#               /carve-harness-create 스킬로 스택에 맞게 맞춤화(검증·보강·절단)
#               비대화형은 HARNESS_COMPONENTS=md,hooks,skills,commands,orchestrator (또는 all)
#               재실행하면 빠진 구성을 추가 설치할 수 있다 (기존 파일은 SKIP)
#   [update]    설치된 하네스를 새 버전으로 패치 — manifest 범위만 갱신
#               curl -fsSL https://raw.githubusercontent.com/claude-code-expert/carve-harness/main/install.sh | bash -s -- update
#               VERSION 비교(같으면 no-op) · 변경 파일은 logs/harness-backup/v<이전>/ 백업
#               설치 때 SKIP된 사용자 파일은 건드리지 않음 · 신규 파일은 설치+manifest 추가
#   [rollback]  직전 업데이트 되돌리기 — 네트워크 불필요
#               bash install.sh rollback
#               최신 백업(logs/harness-backup/v<이전>/) 복원 + 버전 스탬프 복귀.
#               백업은 소비된다 — 연속 실행 시 그 이전 백업으로 내려간다.
#   [setup]     대화형 초기 설정 — 설치 후 프로젝트 맞춤 (모든 항목 엔터로 skip)
#               bash install.sh setup
#               git init · PATH · LSP 서버(vtsls) · LICENSE 생성 · 보호경로 추가 ·
#               도메인 규칙 · 스택 감지 리포트 · GSD 설치 제안
#   [prune]     설치된 하네스에서 프로젝트에 불필요한 구성만 제거 — 네트워크 불필요
#               bash install.sh prune --keep-list <파일>   (KEEP 경로 목록, 나머지 제거)
#               --keep-file <경로>(반복) · --remove-file <경로> · --dry-run(미리보기)
#               제거분은 logs/harness-backup/v<현재>/ 백업 → rollback으로 복원. 코어는 제거 거부.
#               /carve-harness-create 스킬이 프로젝트 분석 후 자동 호출한다.
#   [bootstrap] 하네스 파일이 이미 있으면 → 머신 준비만
#               1) vendor 체크섬 검증  2) .claude/bin 배치(jq·shellcheck)
#               3) jq 없으면 ~/.local/bin/jq  4) 훅 권한 + core.hooksPath
#               5) harness-audit 최종 보고
#
# 환경변수: HARNESS_REPO(기본 claude-code-expert/carve-harness) · HARNESS_REF(기본 main)
#           HARNESS_SRC_DIR(로컬 소스 — 네트워크 생략) · HARNESS_FORCE=1(기존 파일 덮어쓰기/재패치)
set -u

HERE="$PWD"
VBIN="$HERE/vendor/bin"
CBIN="$HERE/.claude/bin"
MANIFEST="$HERE/.claude/harness-manifest.txt"
VSTAMP="$HERE/.claude/harness-version"
warn=0
AUTO_PROJECT=0          # set by choose_setup_mode: 1 = 전체 설치 후 /carve-harness-create로 맞춤 정리
MERGE_SETTINGS_SRC=""   # set in copy loop when the target already has settings.json
say()  { printf '%s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

# Merge harness hook registrations into an EXISTING user settings.json instead of
# skipping it — else the hooks (SessionStart banner, PreToolUse guard, Stop verify,
# handoff) are never registered and the whole harness is silently inert (root cause
# of "banner doesn't show"). Idempotent: hook groups dedup by tojson. User keys
# (permissions.allow, model, own hooks) are preserved; $schema + deny are unioned.
merge_settings_hooks() {  # $1=harness settings (source)  $2=user settings (in place)
  local hs="$1" us="$2" tmp
  command -v jq >/dev/null 2>&1 || { say "ACTION: jq 없어 settings.json 병합 실패 — 훅 수동 등록 필요"; warn=1; return; }
  jq empty "$us" >/dev/null 2>&1 || { say "WARN: 기존 settings.json 파싱 실패 — 병합 건너뜀(훅 수동 등록 필요)"; warn=1; return; }
  tmp=$(mktemp)
  if jq -s '
      .[0] as $h | .[1] as $u |
      $u
      + { "$schema": ($u["$schema"] // $h["$schema"]) }
      + { hooks: (
          ($h.hooks // {}) as $hh | ($u.hooks // {}) as $uh |
          reduce (($hh|keys) + ($uh|keys) | unique)[] as $e
            ({}; .[$e] = (($uh[$e] // []) + ($hh[$e] // []) | unique_by(tojson)))
        ) }
      + { permissions: (($u.permissions // {})
          + { deny: ((($u.permissions.deny // []) + ($h.permissions.deny // [])) | unique) }) }
      + (if ($h.extraKnownMarketplaces // $u.extraKnownMarketplaces) != null then
          { extraKnownMarketplaces:
              (($h.extraKnownMarketplaces // {}) + ($u.extraKnownMarketplaces // {})) }
        else {} end)
      + (if ($h.enabledPlugins // $u.enabledPlugins) != null then
          { enabledPlugins: (($h.enabledPlugins // {}) + ($u.enabledPlugins // {})) }
        else {} end)
    ' "$hs" "$us" > "$tmp" 2>/dev/null && [ -s "$tmp" ] && jq empty "$tmp" >/dev/null 2>&1; then
    mv "$tmp" "$us"
    say "OK: .claude/settings.json — 하네스 훅 6이벤트 + LSP/플러그인 병합 (사용자 설정 보존)"
  else
    rm -f "$tmp"; say "WARN: settings.json 병합 실패 — 훅 수동 등록 필요 (jq/파일 확인)"; warn=1
  fi
}

MODE="${1:-install}"
case "$MODE" in install|update|rollback|setup|prune) ;; *) fail "알 수 없는 모드: $MODE (install|update|rollback|setup|prune)" ;; esac

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

  # 3) LSP 서버 — settings.json의 vtsls/jdtls 플러그인이 호출하는 실행 파일
  if ! command -v vtsls >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    ask "vtsls(TS/JS/React LSP 서버) 미설치 — npm i -g @vtsls/language-server typescript 설치할까? [y/N] "
    if [ "$REPLY" = "y" ]; then
      npm i -g @vtsls/language-server typescript \
        && say "OK: vtsls + typescript 전역 설치" \
        || say "WARN: npm 전역 설치 실패 — 수동 설치 필요"
    fi
  fi
  command -v jdtls >/dev/null 2>&1 \
    || say "NOTE: jdtls(Java LSP) 미설치 — Java 프로젝트면 'brew install jdtls' (JDK 필요)"

  # 4) LICENSE
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

  # 5) 보호 경로 추가 (update-안전: protected-extra.regex는 manifest 밖 → 갱신에도 보존)
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

  # 6) 도메인 규칙 (여러 줄, 빈 줄로 종료)
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

  # 7) 스택 감지 리포트 (질문 없음)
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

  # 8) GSD (SDD 킷)
  if command -v npx >/dev/null 2>&1; then
    ask "GSD(SDD 킷) 설치? npx get-shit-done-cc --local [y/N] "
    [ "$REPLY" = "y" ] && ( cd "$HERE" && npx get-shit-done-cc --local )
  fi

  say "── 설정 끝. 남은 수동 항목: 팀에 AGENTS.md 정본 공지 · 미지원 스택 게이트 추가 ──"
}

# 설치 대상 목록 — uninstall.sh는 설치 시 기록되는 manifest만 신뢰한다.
# 구성(component) 5종 + core. 설치 시 선택 가능, core는 항상 설치.
MD_PATHS=( CLAUDE.md AGENTS.md .cursorrules codex.md .claude/CLAUDE.md .claude/rules docs/rules specs/README.md )
HOOK_PATHS=( .claude/settings.json .claude/hooks .claude/stacks .githooks )   # stacks: 게이트 스택 정의(팩 단위 prune)
SKILL_PATHS=( .claude/skills )
DEV_SKILLS=""   # 배포 제외 스킬 목록(공백 구분). 현재 없음 — carve-guide는 v0.0.13부터 배포 포함. 훅과 build_items·strip이 이 목록을 참조
CMD_PATHS=( .claude/commands )
ORCH_PATHS=( .claude/agents .claude/workflows docs/md/orchestration.md docs/md/fable-team-guide.md docs/md/verify-loop-guide.md )
CORE_PATHS=( VERSION install.sh uninstall.sh vendor )
HARNESS_PATHS=(
  "${MD_PATHS[@]}" "${HOOK_PATHS[@]}" "${SKILL_PATHS[@]}" "${CMD_PATHS[@]}"
  "${ORCH_PATHS[@]}" "${CORE_PATHS[@]}"
)

COMP_ALL="md hooks skills commands orchestrator"
COMPFILE="$HERE/.claude/harness-components"   # 선택 기록 — update가 신규 파일 필터에 사용

comp_of() { # $1=경로 → 구성 이름
  case "$1" in
    .claude/hooks*|.claude/stacks*|.githooks*|.claude/settings.json) echo hooks ;;
    .claude/skills*)   echo skills ;;
    .claude/commands*) echo commands ;;
    .claude/agents*|.claude/workflows*|docs/md/*) echo orchestrator ;;
    CLAUDE.md|AGENTS.md|.cursorrules|codex.md|.claude/CLAUDE.md|.claude/rules*|docs/rules*|specs/README.md) echo md ;;
    *) echo core ;;
  esac
}
comp_in() { case " $COMPONENTS " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

# ── 구성 선택: 체크박스 TUI ──────────────────────────────────────────────────
# 전체 항목을 섹션별로 펼쳐 표시. ↑↓/jk 이동 · 스페이스 토글(섹션 행=하위 일괄) ·
# 1-5 섹션 점프 · a 전체 토글 · 엔터 설치. 기본 전체 선택 → 엔터만 치면 전체 설치.
# env HARNESS_COMPONENTS / tty 없음(비대화형)은 기존 구성 단위 경로로 폴백.
# 헤더 행은 IT_PATH가 빈 문자열 — 별도 플래그 배열 없이 이걸로 판별한다.
IT_PATH=(); IT_LABEL=(); IT_SEC=(); IT_ON=(); HDR_IDX=()
SELECTED_PATHS=()

add_hdr() { HDR_IDX+=("${#IT_PATH[@]}"); IT_PATH+=(""); IT_SEC+=("$1"); IT_ON+=(1); IT_LABEL+=("$2"); }
add_it()  { IT_PATH+=("$1"); IT_SEC+=("$2"); IT_ON+=(1); IT_LABEL+=("$3"); }

build_items() { # $SRC 기준으로 실재 항목만 나열
  local p f idx next i
  add_hdr md "필수 md"
  for p in "${MD_PATHS[@]}"; do [ -e "$SRC/$p" ] && add_it "$p" md "$p"; done
  add_hdr hooks "훅 (가드·게이트)"
  for p in "${HOOK_PATHS[@]}"; do [ -e "$SRC/$p" ] && add_it "$p" hooks "$p"; done
  add_hdr skills "스킬"
  for f in "$SRC"/.claude/skills/*; do
    [ -e "$f" ] || continue
    case " $DEV_SKILLS " in *" ${f##*/} "*) continue ;; esac   # 배포 제외 스킬은 TUI 목록에서도 숨김
    add_it ".claude/skills/${f##*/}" skills "${f##*/}"
  done
  add_hdr commands "커맨드"
  for f in "$SRC"/.claude/commands/*; do [ -e "$f" ] && add_it ".claude/commands/${f##*/}" commands "${f##*/}"; done
  add_hdr orchestrator "오케스트레이터"
  for p in "${ORCH_PATHS[@]}"; do   # 정본 목록 순회 — agents만 항목 단위로 전개
    if [ "$p" = ".claude/agents" ]; then
      for f in "$SRC"/.claude/agents/*; do [ -e "$f" ] && add_it ".claude/agents/${f##*/}" orchestrator "agents/${f##*/}"; done
    else
      [ -e "$SRC/$p" ] && add_it "$p" orchestrator "$p"
    fi
  done
  for ((i = 0; i < ${#HDR_IDX[@]}; i++)); do   # 헤더에 항목 수 표기 — 섹션은 연속 구간
    idx=${HDR_IDX[$i]}
    if [ $((i + 1)) -lt "${#HDR_IDX[@]}" ]; then next=${HDR_IDX[$((i + 1))]}; else next=${#IT_PATH[@]}; fi
    IT_LABEL[$idx]="${IT_LABEL[$idx]} ($((next - idx - 1)))"
  done
}

sec_state() { # $1=섹션 → 2=전체 on · 1=부분 · 0=전체 off
  local i on=0 off=0
  for ((i = 0; i < ${#IT_PATH[@]}; i++)); do
    [ -n "${IT_PATH[$i]}" ] || continue
    [ "${IT_SEC[$i]}" = "$1" ] || continue
    [ "${IT_ON[$i]}" = 1 ] && on=1 || off=1
  done
  if [ "$off" -eq 0 ]; then echo 2; elif [ "$on" -eq 0 ]; then echo 0; else echo 1; fi
}

toggle_sec() {
  local new i
  [ "$(sec_state "$1")" = 2 ] && new=0 || new=1
  for ((i = 0; i < ${#IT_PATH[@]}; i++)); do
    [ -n "${IT_PATH[$i]}" ] && [ "${IT_SEC[$i]}" = "$1" ] && IT_ON[$i]=$new
  done
}

toggle_all() {
  local new=0 i
  for ((i = 0; i < ${#IT_PATH[@]}; i++)); do
    [ -n "${IT_PATH[$i]}" ] && [ "${IT_ON[$i]}" = 0 ] && new=1
  done
  for ((i = 0; i < ${#IT_PATH[@]}; i++)); do
    [ -n "${IT_PATH[$i]}" ] && IT_ON[$i]=$new
  done
}

draw_menu() { # $1=표시 행 수 — 커서 따라 스크롤, 매번 같은 줄 수 재그리기
  local rows=$1 total=${#IT_PATH[@]} i end mark cur st
  [ "$CURSOR" -lt "$TOP" ] && TOP=$CURSOR
  [ "$CURSOR" -ge $((TOP + rows)) ] && TOP=$((CURSOR - rows + 1))
  [ "$TOP" -gt $((total - rows)) ] && TOP=$((total - rows))
  [ "$TOP" -lt 0 ] && TOP=0
  [ "$DRAWN" -gt 0 ] && printf '\033[%dA' "$DRAWN"
  end=$((TOP + rows)); [ "$end" -gt "$total" ] && end=$total
  for ((i = TOP; i < end; i++)); do
    cur=' '; [ "$i" -eq "$CURSOR" ] && cur='>'
    if [ -z "${IT_PATH[$i]}" ]; then
      st=$(sec_state "${IT_SEC[$i]}")
      case "$st" in 2) mark='x' ;; 1) mark='~' ;; *) mark=' ' ;; esac
      printf '\033[K%s [%s] ── %s ──\n' "$cur" "$mark" "${IT_LABEL[$i]}"
    else
      mark=' '; [ "${IT_ON[$i]}" = 1 ] && mark='x'
      printf '\033[K%s   [%s] %s\n' "$cur" "$mark" "${IT_LABEL[$i]}"
    fi
  done
  DRAWN=$((end - TOP))
}

menu_loop() {
  local key seq lines rows total=${#IT_PATH[@]}
  lines=$(stty size < "$ASK_IN" 2>/dev/null | awk '{print $1}')
  case "$lines" in '' | *[!0-9]*) lines=0 ;; esac
  [ "$lines" -ge 8 ] || lines=1000   # 감지 실패(파이프 입력 등) → 전체 출력
  rows=$((lines - 3)); [ "$rows" -gt "$total" ] && rows=$total
  CURSOR=0; TOP=0; DRAWN=0
  say "── 설치 구성 선택 ── ↑↓/jk 이동 · 스페이스 토글(섹션 행=하위 일괄) · 1-5 섹션 · a 전체 · 엔터 설치"
  while :; do
    draw_menu "$rows"
    IFS= read -rsn1 key < "$ASK_IN" 2>/dev/null || break   # EOF/입력 불가 → 현재 상태로 확정
    case "$key" in
      "") break ;;   # 엔터 → 설치
      j) CURSOR=$((CURSOR + 1)) ;;
      k) CURSOR=$((CURSOR - 1)) ;;
      $'\033')
        IFS= read -rsn2 -t 1 seq < "$ASK_IN" 2>/dev/null || seq=""
        case "$seq" in
          '[A') CURSOR=$((CURSOR - 1)) ;;
          '[B') CURSOR=$((CURSOR + 1)) ;;
        esac ;;
      ' ')
        if [ -z "${IT_PATH[$CURSOR]}" ]; then toggle_sec "${IT_SEC[$CURSOR]}"
        else IT_ON[$CURSOR]=$((1 - ${IT_ON[$CURSOR]})); fi ;;
      a) toggle_all ;;
      [1-9]) [ "$key" -le "${#HDR_IDX[@]}" ] && CURSOR=${HDR_IDX[$((key - 1))]} ;;
    esac
    [ "$CURSOR" -lt 0 ] && CURSOR=0
    [ "$CURSOR" -ge "$total" ] && CURSOR=$((total - 1))
  done
}

prefix_full() { # $1=디렉토리 — 하위 항목 전부 선택이면 0 (헤더는 빈 경로라 자연 제외)
  local i
  for ((i = 0; i < ${#IT_PATH[@]}; i++)); do
    case "${IT_PATH[$i]}" in "$1"/*) [ "${IT_ON[$i]}" = 1 ] || return 1 ;; esac
  done
  return 0
}

collect_selected() { # → $COMPONENTS + $SELECTED_PATHS. 전체 선택 디렉토리는 coarse 경로로 축약.
  local i p sec full="" all_on=1
  COMPONENTS=""
  for sec in $COMP_ALL; do
    case "$(sec_state "$sec")" in
      2) COMPONENTS="$COMPONENTS $sec" ;;
      1) COMPONENTS="$COMPONENTS $sec"; all_on=0 ;;
      0) all_on=0 ;;
    esac
  done
  COMPONENTS="${COMPONENTS# }"
  # build_items가 항목 단위로 전개하는 디렉토리 3종 — 전개 지점 변경 시 함께 수정
  for p in .claude/skills .claude/commands .claude/agents; do
    prefix_full "$p" && full="$full $p"
  done
  SELECTED_PATHS=()
  for p in $full; do SELECTED_PATHS+=("$p"); done
  for ((i = 0; i < ${#IT_PATH[@]}; i++)); do
    [ -n "${IT_PATH[$i]}" ] || continue
    [ "${IT_ON[$i]}" = 1 ] || continue
    p="${IT_PATH[$i]}"
    case " $full " in *" ${p%/*} "*) continue ;; esac   # 축약 디렉토리 소속 → 개별 기록 생략
    SELECTED_PATHS+=("$p")
  done
  if [ -z "$COMPONENTS" ]; then
    say "선택 없음 — core만 설치"
  elif [ "$all_on" -eq 1 ]; then
    say "구성 선택: 전체"
  else
    say "구성 선택: $COMPONENTS (${#SELECTED_PATHS[@]} 항목)"
  fi
}

sel_from_components() { # env/비대화형 — 구성 단위 coarse 경로
  local p c
  SELECTED_PATHS=()
  for p in "${HARNESS_PATHS[@]}"; do
    c=$(comp_of "$p")
    [ "$c" = "core" ] && continue
    comp_in "$c" && SELECTED_PATHS+=("$p")
  done
}

choose_setup_mode() { # 설치 최상단: 맞춤 구축(전체+스킬 정리) vs 수동 선택. AUTO_PROJECT 설정.
  [ -n "${HARNESS_COMPONENTS:-}" ] && return    # env 설치 → 무변경 (회귀 가드)
  { : < "$ASK_IN"; } 2>/dev/null || return      # tty 없음 → 무변경 (회귀 가드)
  say "── 하네스 구축 방식 ──"
  say "  [1] 프로젝트 분석 후 맞춤 하네스 구축 (권장)"
  say "  [2] 수동 컴포넌트 선택"
  ask "선택 [1/2] (엔터=1): "
  case "$REPLY" in
    2) return ;;                    # 기존 체크박스 TUI로 진행
    *) AUTO_PROJECT=1 ;;            # 빈 엔터/1/기타 = 맞춤(권장)
  esac
}

select_components() { # → $COMPONENTS + $SELECTED_PATHS. env > AUTO_PROJECT > TUI > 전체.
  if [ "$AUTO_PROJECT" = 1 ]; then               # 맞춤 구축 → 전체 설치(스킬이 이후 정리)
    COMPONENTS="$COMP_ALL"; say "구성 선택: 전체 (프로젝트 맞춤 예정 — /carve-harness-create)"
    sel_from_components
    return
  fi
  if [ -n "${HARNESS_COMPONENTS:-}" ]; then
    [ "$HARNESS_COMPONENTS" = "all" ] && COMPONENTS="$COMP_ALL" \
      || COMPONENTS=$(printf '%s' "$HARNESS_COMPONENTS" | tr ',' ' ')
    say "구성 선택(env): $COMPONENTS"
    sel_from_components
    return
  fi
  if ! { : < "$ASK_IN"; } 2>/dev/null; then   # tty 없음 → 전체
    COMPONENTS="$COMP_ALL"; say "구성 선택: 전체"
    sel_from_components
    return
  fi
  build_items
  menu_loop
  collect_selected
  comp_in hooks || say "NOTE: 훅 미선택 — 차단 가드·커밋 게이트 비활성 (하네스 제약 기둥 없음)"
}

# ── prune 헬퍼 ────────────────────────────────────────────────────────────────
# manifest의 coarse 디렉토리 줄을 현재 on-disk per-child 줄로 펼쳐 stdout에 출력(원본 불변).
# 파일 단위 제거의 선행. rules 하위는 dir 단위, docs/rules(code-convention 참조본)는
# 파일 단위로. 멱등: 이미 펼쳐진 줄(exact 매치 아님)은 그대로 통과.
prune_expand_manifest() {
  local p f g
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    case "$p" in
      .claude/skills|.claude/commands|.claude/agents|.claude/hooks|.claude/stacks)
        if [ -d "$HERE/$p" ]; then
          for f in "$HERE/$p"/*; do [ -e "$f" ] && printf '%s\n' "$p/${f##*/}"; done
        else printf '%s\n' "$p"; fi ;;
      .claude/rules)
        if [ -d "$HERE/$p" ]; then
          for f in "$HERE/$p"/*; do [ -e "$f" ] && printf '%s\n' "$p/${f##*/}"; done
        else printf '%s\n' "$p"; fi ;;
      docs/rules)
        if [ -d "$HERE/$p" ]; then
          for f in "$HERE/$p"/*; do
            [ -e "$f" ] || continue
            if [ -d "$f" ]; then
              for g in "$f"/*; do [ -e "$g" ] && printf '%s\n' "$p/${f##*/}/${g##*/}"; done
            else printf '%s\n' "$p/${f##*/}"; fi
          done
        else printf '%s\n' "$p"; fi ;;
      *) printf '%s\n' "$p" ;;
    esac
  done < "$MANIFEST"
}

# COMPFILE 재계산 — 살아남은 manifest 항목의 구성만 남긴다(완전 프루닝된 구성은 탈락 →
# 이후 update가 comp_in 게이트로 SKIP, 부활 방지).
prune_update_compfile() {
  local p c
  { while IFS= read -r p; do
      [ -n "$p" ] || continue
      c=$(comp_of "$p"); [ "$c" = "core" ] && continue
      printf '%s\n' "$c"
    done < "$MANIFEST"; } | sort -u > "$COMPFILE"
}

# $1=keepfile $2=removefile $3=keepmode(1/0) $4=dry(1/0)
prune_run() {
  local keepf="$1" removef="$2" keepmode="$3" dry="$4"
  if [ "$keepmode" = 1 ] && [ ! -s "$keepf" ]; then
    fail "빈 keep-list — 전체 제거 방지. 최소 1개 --keep-file/--keep-list 필요"
  fi
  # PROTECTED 코어 — keep/remove 로직 이전에 무조건 유지(하네스 3기둥·크로스에이전트 진입·스크립트).
  local prot='^(CLAUDE\.md|AGENTS\.md|\.cursorrules|codex\.md|\.claude/CLAUDE\.md|\.claude/settings\.json|\.claude/hooks(/|$)|\.claude/rules/safety\.md|\.claude/rules/common(/|$)|vendor(/|$)|\.githooks(/|$)|VERSION|install\.sh|uninstall\.sh)'
  local OLDV BAK tmp work removed=0 p remove
  OLDV=$(cat "$VSTAMP" 2>/dev/null | tr -d '[:space:]'); OLDV="${OLDV:-unknown}"
  BAK="$HERE/logs/harness-backup/v$OLDV"   # update와 동일 경로 → rollback이 그대로 복원
  work=$(mktemp); prune_expand_manifest > "$work"   # 확장본(원본 불변) — dry-run 안전
  tmp=$(mktemp)
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    # eval-java.sh는 Java 전용 스코어러 → 프루닝 허용(archunit과 묶여 제거, AUDIT-08 스킵).
    # 나머지 훅은 언어 무관 코어라 protected.
    if [ "$p" != ".claude/hooks/eval-java.sh" ] && printf '%s' "$p" | grep -Eq "$prot"; then
      grep -qxF "$p" "$removef" 2>/dev/null && say "PROTECTED (제거 거부): $p"
      printf '%s\n' "$p" >> "$tmp"; continue
    fi
    remove=0
    grep -qxF "$p" "$removef" 2>/dev/null && remove=1
    [ "$keepmode" = 1 ] && ! grep -qxF "$p" "$keepf" 2>/dev/null && remove=1
    if [ "$remove" = 1 ]; then
      if [ ! -e "$HERE/$p" ]; then say "SKIP: $p (이미 없음)"; continue; fi
      if [ "$dry" = 1 ]; then say "WOULD REMOVE: $p"; printf '%s\n' "$p" >> "$tmp"; removed=$((removed + 1)); continue; fi
      mkdir -p "$BAK/$(dirname "$p")"
      cp -R "$HERE/$p" "$BAK/$p" 2>/dev/null
      rm -rf "${HERE:?}/$p"
      say "PRUNED: $p (백업: logs/harness-backup/v$OLDV/$p)"
      removed=$((removed + 1))
    else
      printf '%s\n' "$p" >> "$tmp"
    fi
  done < "$work"
  rm -f "$work"
  if [ "$dry" = 1 ]; then rm -f "$tmp"; say "── dry-run: $removed 개 제거 예정 (변경 없음) ──"; return; fi
  mv "$tmp" "$MANIFEST"
  prune_update_compfile
  say "── prune 완료: $removed 개 제거 · 백업 logs/harness-backup/v$OLDV/ (rollback 복원 가능) ──"
}

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

# ── [prune] ──────────────────────────────────────────────────────────────────
# 네트워크 불필요 — 처리 후 bootstrap로 fall-through(끝에서 harness-audit로 결과 검증).
if [ "$MODE" = "prune" ]; then
  [ -f "$MANIFEST" ] || fail "manifest 없음 — 설치된 하네스가 아님. install.sh(설치)를 먼저 실행"
  shift 2>/dev/null || true   # 'prune' 제거
  KEEPTMP=$(mktemp); REMOVETMP=$(mktemp); KEEPMODE=0; DRY=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --keep-list)  shift; [ -f "${1:-}" ] || fail "--keep-list 파일 없음: ${1:-}"
                    grep -vE '^[[:space:]]*(#|$)' "$1" >> "$KEEPTMP"; KEEPMODE=1 ;;
      --keep-file)  shift; [ -n "${1:-}" ] && printf '%s\n' "$1" >> "$KEEPTMP"; KEEPMODE=1 ;;
      --remove-file) shift; [ -n "${1:-}" ] && printf '%s\n' "$1" >> "$REMOVETMP" ;;
      --dry-run)    DRY=1 ;;
      *) rm -f "$KEEPTMP" "$REMOVETMP"; fail "prune: 알 수 없는 인자 $1 (--keep-list|--keep-file|--remove-file|--dry-run)" ;;
    esac
    shift 2>/dev/null || break
  done
  if [ "$KEEPMODE" = 0 ] && [ ! -s "$REMOVETMP" ]; then
    rm -f "$KEEPTMP" "$REMOVETMP"; fail "prune: --keep-list/--keep-file 또는 --remove-file 필요"
  fi
  prune_run "$KEEPTMP" "$REMOVETMP" "$KEEPMODE" "$DRY"
  rm -f "$KEEPTMP" "$REMOVETMP"
  [ "$DRY" = 1 ] && exit 0   # dry-run은 bootstrap/audit 생략
fi

# ── [fetch / update] ─────────────────────────────────────────────────────────
NEED_FETCH=0
if [ "$MODE" = "update" ]; then
  [ -f "$MANIFEST" ] || fail "manifest 없음 — 설치된 하네스가 아님. install.sh(설치)를 먼저 실행"
  NEED_FETCH=1
elif [ "$MODE" = "install" ] && [ ! -f "$HERE/.claude/hooks/pretool-guard.sh" ]; then
  NEED_FETCH=1
elif [ "$MODE" = "install" ] && [ -n "${HARNESS_COMPONENTS:-}" ]; then
  NEED_FETCH=1   # 설치 후 구성 추가: HARNESS_COMPONENTS=skills bash install.sh
fi
if [ "$NEED_FETCH" -eq 1 ]; then
  SRC="${HARNESS_SRC_DIR:-}"
  TMPD=""
  if [ -z "$SRC" ]; then
    command -v curl >/dev/null 2>&1 || fail "curl 없음 — 오프라인이면 HARNESS_SRC_DIR=/복사된/하네스 로 실행"
    command -v tar  >/dev/null 2>&1 || fail "tar 없음"
    REPO="${HARNESS_REPO:-claude-code-expert/carve-harness}"
    REF="${HARNESS_REF:-main}"
    TMPD=$(mktemp -d)
    trap '[ -n "$TMPD" ] && rm -rf "$TMPD"' EXIT
    say "fetch: https://github.com/$REPO @ $REF"
    curl -fsSL "https://codeload.github.com/$REPO/tar.gz/$REF" | tar -xz -C "$TMPD" --strip-components=1 \
      || fail "다운로드 실패 — 레포/브랜치 확인"
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
    # 설치 때 선택한 구성만 신규 파일 추가 대상 — 기록 없으면(구버전 설치) 전체
    COMPONENTS=$(tr '\n' ' ' < "$COMPFILE" 2>/dev/null); COMPONENTS="${COMPONENTS:-$COMP_ALL}"
    BAK="$HERE/logs/harness-backup/v$OLDV"   # logs/는 gitignore — 백업 소음 없음
    # ponytail: 경로 목록은 실행 중인 스크립트 기준 — 신규 경로까지 받으려면 curl|bash 업데이트가 정본
    # manifest의 모든 라인이 하네스 설치분(부분 선택의 fine 경로 포함) — 전부 패치 대상.
    # coarse 경로 중복은 2차 순회에서 diff 동일 → no-op으로 흡수된다.
    UP_PATHS=( "${HARNESS_PATHS[@]}" )
    while IFS= read -r fp; do
      [ -n "$fp" ] && UP_PATHS+=("$fp")
    done < "$MANIFEST"
    for p in "${UP_PATHS[@]}"; do
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
        c=$(comp_of "$p")
        if [ "$c" != "core" ] && ! comp_in "$c"; then
          say "SKIP: $p ($c 구성 미선택 — 추가하려면 install 재실행)"
          continue
        fi
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
    choose_setup_mode         # 최상단: 맞춤 구축(전체+정리) vs 수동 선택
    select_components
    mkdir -p "$HERE/.claude"   # 나머지 경로는 복사 루프가 생성 — 미리 만들면 SKIP 오탐
    touch "$MANIFEST"          # 재실행으로 구성 추가 시 기존 기록 보존
    for p in ${SELECTED_PATHS[@]+"${SELECTED_PATHS[@]}"} "${CORE_PATHS[@]}"; do
      [ -e "$SRC/$p" ] || continue
      # settings.json은 훅 등록의 유일한 자리 — 기존 파일이면 스킵이 아니라 병합한다
      # (스킵하면 훅 미등록 → 배너·가드·검증 전부 무력화). 병합은 jq 보장 후 (4.5)에서.
      if [ "$p" = ".claude/settings.json" ] && [ -e "$HERE/$p" ] && [ "${HARNESS_FORCE:-0}" != "1" ]; then
        MERGE_SETTINGS_SRC="$SRC/$p"
        say "MERGE 예약: .claude/settings.json — 기존 파일에 하네스 훅 병합 (부트스트랩 후)"
        continue
      fi
      if [ -e "$HERE/$p" ] && [ "${HARNESS_FORCE:-0}" != "1" ]; then
        # Hook dirs must never stay partial: a pre-existing .claude/hooks (foreign,
        # emptied by uninstall, or an interrupted install) made this SKIP the whole
        # dir, dropping lib-protected.sh — the pre-commit gate then sourced a missing
        # file and fail-closed EVERY commit. Fill only MISSING children instead.
        # ponytail: one-level heal — nested partial hook subdirs are not a real case.
        case "$p" in
          .claude/hooks | .claude/stacks | .githooks)
            if [ -d "$SRC/$p" ] && [ -d "$HERE/$p" ]; then
              healed=0
              for hc in "$SRC/$p"/*; do
                [ -e "$hc" ] || continue
                hrel="$p/${hc##*/}"
                [ -e "$HERE/$hrel" ] && continue
                cp -R "$hc" "$HERE/$hrel" && { say "HEAL: $hrel (누락 복구)"; healed=1; }
              done
              [ "$healed" -eq 1 ] && { grep -qx "$p" "$MANIFEST" 2>/dev/null || printf '%s\n' "$p" >> "$MANIFEST"; }
              continue
            fi ;;
        esac
        say "SKIP: $p 이미 존재 (덮어쓰려면 HARNESS_FORCE=1)"
        warn=1
        continue
      fi
      mkdir -p "$HERE/$(dirname "$p")"
      cp -R "$SRC/$p" "$HERE/$p"
      grep -qx "$p" "$MANIFEST" 2>/dev/null || printf '%s\n' "$p" >> "$MANIFEST"
      say "OK: $p"
    done
    # 선택 기록 저장 — 재실행 시 이전 선택과 합집합 (update의 신규 파일 필터 기준)
    [ -f "$COMPFILE" ] && COMPONENTS="$COMPONENTS $(tr '\n' ' ' < "$COMPFILE")"
    COMPONENTS=$(printf '%s\n' $COMPONENTS | sort -u | tr '\n' ' ')
    printf '%s\n' $COMPONENTS > "$COMPFILE"
    [ -f "$SRC/VERSION" ] && tr -d '[:space:]' < "$SRC/VERSION" > "$VSTAMP"

    # 맞춤 구축: 세션에서 /carve-harness-create가 읽고 지우는 마커 (jq 불요, 평문 3줄)
    if [ "$AUTO_PROJECT" = 1 ]; then
      { echo pending
        printf 'version=%s\n' "$(tr -d '[:space:]' < "$SRC/VERSION" 2>/dev/null)"
      } > "$HERE/.claude/harness-create-pending"
    fi

    # .gitignore — 하네스 런타임 산출물 무시 블록 (마커로 관리, uninstall이 제거)
    if ! grep -q '>>> harness' "$HERE/.gitignore" 2>/dev/null; then
      {
        echo '# >>> harness (managed by install.sh) >>>'
        echo 'logs/'
        echo '.claude/bin/'
        echo '.claude/harness-manifest.txt'
        echo '.claude/harness-version'
        echo '.claude/harness-components'
        echo '.claude/harness-create-pending'
        echo 'specs/HANDOFF.md'
        echo '# <<< harness <<<'
      } >> "$HERE/.gitignore"
      say "OK: .gitignore 하네스 블록 추가"
    fi
  fi
fi

# 배포 제외 스킬(DEV_SKILLS): coarse cp -R가 함께 복사했더라도 소비자 설치본에서 제거한다.
for _ds in $DEV_SKILLS; do
  [ -e "$HERE/.claude/skills/$_ds" ] && rm -rf "${HERE:?}/.claude/skills/$_ds" && say "DEV-SKIP: .claude/skills/$_ds (배포 제외)"
done

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
elif [ -f "$HERE/.claude/hooks/pretool-guard.sh" ]; then
  fail "jq 없음 + 내장본도 없음 — 훅이 fail-closed로 모든 쓰기를 차단한다. jq 확보 필수"
else
  say "WARN: jq 없음 — 훅 구성 미설치라 진행 (훅 추가 설치 시 jq 필수)"
  warn=1
fi

# (4) permissions + agent-agnostic commit gate.
chmod +x "$HERE"/.claude/hooks/*.sh "$HERE"/.githooks/* 2>/dev/null
say "OK: 훅 실행 권한"
if git -C "$HERE" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git -C "$HERE" config core.hooksPath .githooks
  say "OK: git core.hooksPath=.githooks (pre-commit 게이트 활성)"
else
  say "WARN: git 레포 아님 — 커밋 게이트 비활성. git init 후 재실행 권장"
  warn=1
fi

# (4.4) merge harness hooks into a pre-existing settings.json (jq now guaranteed).
if [ -n "$MERGE_SETTINGS_SRC" ] && [ -f "$MERGE_SETTINGS_SRC" ]; then
  merge_settings_hooks "$MERGE_SETTINGS_SRC" "$HERE/.claude/settings.json"
fi

# (4.45) LSP 서버 바이너리 — settings.json이 선언한 vtsls/jdtls 플러그인은
# 마켓플레이스 신뢰 승인 후 자동 설치되지만, 서버 실행 파일은 PATH에 있어야 한다.
if [ -f "$HERE/.claude/settings.json" ] \
   && jq -e '.enabledPlugins["vtsls@claude-code-lsps"]' "$HERE/.claude/settings.json" >/dev/null 2>&1; then
  command -v vtsls >/dev/null 2>&1 \
    || say "NOTE: vtsls(TS/JS/React LSP 서버) 미설치 — 'npm i -g @vtsls/language-server typescript' 또는 'bash install.sh setup'"
  command -v jdtls >/dev/null 2>&1 \
    || say "NOTE: jdtls(Java LSP 서버) 미설치 — Java 프로젝트면 'brew install jdtls' (JDK 필요)"
fi

# (4.5) interactive project setup.
[ "$MODE" = "setup" ] && run_setup

# (5) final state report.
say "---"
if [ ! -f "$HERE/.claude/hooks/harness-audit.sh" ]; then
  say "audit 생략 — 훅 구성 미설치 (추가하려면 install 재실행 후 훅 섹션 선택)"
  say "설치 완료(부분 구성) — 위 WARN/SKIP 항목 확인."
elif CLAUDE_PROJECT_DIR="$HERE" bash "$HERE/.claude/hooks/harness-audit.sh"; then
  say "---"
  [ "$warn" -eq 0 ] && say "설치 완료 — 하네스 전 게이트 활성." \
                    || say "설치 완료(경고 있음) — 위 WARN/ACTION/SKIP 항목 확인."
  if command -v node >/dev/null 2>&1; then
    say "모드: ponytail(게으른 시니어) 다음 세션부터 자동 활성 — 해제: 'normal mode'"
  else
    say "모드: ponytail은 node 미설치로 비활성 — node 설치 시 자동 활성"
  fi
  if [ "$MODE" = "install" ]; then
    # 배너는 carve-harness-create 스킬이 설치됐는지로 판단한다(AUTO_PROJECT 아님):
    # curl|bash 비대화형은 tty가 없어 choose_setup_mode가 스킵되지만 전체 설치라
    # 스킬이 깔린다 — 그 경우에도 /carve-harness-create 안내가 나와야 한다.
    if [ -f "$HERE/.claude/skills/carve-harness-create/SKILL.md" ]; then
      say ""
      say "┌─────────────────────────────────────────────────────────────┐"
      say "│  맞춤 하네스 구축 예약됨 — 전체 설치 완료, 지금 바로 동작   │"
      say "└─────────────────────────────────────────────────────────────┘"
      say "프로젝트를 전수 분석해 이 스택에 맞게 맞춤화하려면"
      say "Claude Code 세션에서 다음을 실행하세요:"
      say ""
      say "    /carve-harness-create"
      say ""
      say "설정 검증(CLAUDE.md·AGENTS.md 오류 제안) · 보강(누락 규칙·도구 안내) ·"
      say "절단(불필요 구성 제거)을 통합 제안하고, 1회 확인 후 적용 + evaluator 평가표."
      say "맞춤화하지 않아도 하네스는 정상 동작합니다(전체 구성 유지)."
    else
      say "다음 단계: bash install.sh setup — 대화형 초기 설정 (git·PATH·LICENSE·보호경로·도메인 규칙·GSD)"
    fi
  fi
else
  say "---"
  say "설치됐으나 audit FAIL 항목 존재 — 위 FAIL 라인 해결 후 재실행."
  exit 1
fi
