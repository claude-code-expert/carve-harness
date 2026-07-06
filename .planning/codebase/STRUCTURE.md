---
doc: STRUCTURE
mapped: 2026-07-06
last_mapped_commit: (not a git repo)
---

# STRUCTURE — 디렉토리 구조

## 전체 레이아웃 (실측)

```
harness/
├── CLAUDE.md                       # 제약: 전역 가드레일 (3기둥·절대금지·스택감지)
├── AGENTS.md                       # 에이전트 표준 (역할·에스컬레이션 포맷)
├── RULES.md                        # 룰 위치 인덱스
├── README.md                       # 드롭인 설치·사용법
├── HARNESS-TEMPLATE-MANUAL.md      # 구조·기능·사용 매뉴얼 (239줄, 가장 상세)
├── install.md                      # ⚠️ 빈 파일 (0 bytes)
├── specs/                          # 상태 기둥: SDD 산출물 루트
│   └── README.md                   #   (HANDOFF.md·DECISIONS.md가 여기 쌓임 — 아직 없음)
└── .claude/
    ├── settings.json               # 훅 등록 + permissions.deny
    ├── hooks/                      # 훅 4종 (Bash)
    │   ├── pretool-guard.sh        #   PreToolUse — 보호파일 차단
    │   ├── posttool-format.sh      #   PostToolUse — 언어감지 포맷
    │   ├── stop-verify.sh          #   Stop — 빌드/타입 게이트
    │   └── session-handoff.sh      #   SessionStart/PreCompact — 핸드오프
    ├── agents/                     # 서브에이전트 5종
    │   ├── evaluator.md            #   SC·타입/계약 검증 (sonnet)
    │   ├── code-reviewer.md        #   가독성·구조·중복 (sonnet)
    │   ├── security-reviewer.md    #   시크릿·인가·인젝션 (sonnet)
    │   ├── silent-failure-hunter.md#   빈 catch·무시된 error (haiku)
    │   └── state-reviewer.md       #   상태경계·트랜잭션 (sonnet)
    ├── commands/                   # 슬래시 커맨드 5종
    │   ├── plan.md · verify.md · review.md · commit.md · harness-audit.md
    ├── skills/                     # 스킬 2종
    │   ├── handoff/SKILL.md        #   specs/HANDOFF.md 인계
    │   └── changelog/SKILL.md      #   specs/DECISIONS.md 결정기록
    └── rules/                      # 경로 glob 규칙
        ├── common/                 #   paths: **/*
        │   ├── security.md · testing.md · git-workflow.md
        ├── java-spring/patterns.md #   paths: **/*.java
        └── react-next/patterns.md  #   paths: **/*.ts, **/*.tsx
```

## 규모

- 총 ~498줄, ~25개 파일. 가장 큰 파일 `HARNESS-TEMPLATE-MANUAL.md` (239줄). 나머지는 대부분 4~12줄 스텁.
- Git 저장소 아님 (`.git` 없음).

## 핵심 위치 (무엇을 어디서 고치나)

| 하고 싶은 것 | 위치 |
|-------------|------|
| 전역 금지/도메인 규칙 | `CLAUDE.md` "절대 금지" |
| 차단 대상 파일 패턴 | `.claude/hooks/pretool-guard.sh` case |
| 포맷터 변경 | `.claude/hooks/posttool-format.sh` case |
| 검증 명령(빌드/테스트) | `.claude/hooks/stop-verify.sh` |
| 스택별 규칙 | `.claude/rules/<stack>/` |
| 새 커맨드/에이전트/스킬 | `.claude/commands|agents|skills/` |
| 훅 이벤트 등록 | `.claude/settings.json` |

## 명명 규칙

- 문서·규칙·에이전트·스킬·커맨드: `kebab-case.md`, 소문자.
- 훅: `<이벤트-역할>.sh` (`pretool-guard`, `posttool-format`, `stop-verify`, `session-handoff`).
- 에이전트/스킬/규칙: YAML frontmatter 필수 (`name`, `description`, `paths`/`tools`/`model`).
- 루트 대문자 문서 = 전역 계약 (`CLAUDE.md`, `AGENTS.md`, `RULES.md`, `README.md`).
