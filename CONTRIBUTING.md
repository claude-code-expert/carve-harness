# CONTRIBUTING.md — carve-harness 기여 가이드

carve-harness에 기여해주셔서 감사합니다. 이 문서는 개발 환경 셋업, 자산 추가 규약, PR 절차를 다룹니다.

## 개발 환경 셋업

```bash
git clone https://github.com/claude-code-expert/carve-harness.git
cd carve-harness

# vendor 동기화 (submodule 방식 기준 — 최종 방식은 requirement.md OI-1 참조)
git submodule update --init --recursive

npm install
```

> 요구사항: Node.js ≥ 18.

## vendor 동기화 규칙

- `vendor/openharness`, `vendor/subagents`는 **직접 수정 금지** (읽기 전용 / 자산 소스).
- 업스트림 반영은 submodule 포인터 또는 subtree pull로만 한다.
- OpenHarness는 변경이 잦으므로 **핀 버전**으로만 올린다. 임의 최신 추적 금지.

## 자산 추가 (새 스킬·훅·커맨드·에이전트)

새 베이스 자산은 `assets/` 아래에 둔다. generator가 인식하도록 다음 규약을 지킨다.

### 스킬
- 위치: `assets/skills/<skill-name>/SKILL.md`
- frontmatter 필수: `name`, `description` (자동 트리거 근거)
- 본문이 길면 `references/`로 분리 (Progressive Disclosure)
- 출처: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview

```yaml
---
name: example-skill
description: 무엇을 하고 언제 쓰는지 명확히. 트리거 문구 포함.
allowed-tools: Read, Grep, Glob
---
```

### 서브에이전트
- 위치: `assets/agents/<name>.md`
- frontmatter: `name`·`description`·`tools`·`model`·`maxTurns`
- 단일 책임 원칙. 도구 권한은 프롬프트가 아니라 `tools` 필드로 하드 제약.
- Write 권한 보유 시 `## Boundaries` 섹션 필수.

### 훅
- 위치: `assets/hooks/<name>.sh`
- 결정적 차단은 `PreToolUse`(exit code 2로 차단), 포맷·린트는 `PostToolUse`.
- OS 분기 필요 시 macOS/Linux/WSL 모두 처리 (`osascript`/`notify-send`/`powershell`).

### 커맨드
- 위치: `assets/commands/<name>.md`
- `/carve-*` 네이밍, `allowed-tools` 명시.

## 코드 스타일 / 검증 (필수)

커밋 전 모든 산출물의 syntax를 검증한다.

```bash
node --check bin/carve.js src/*.js     # JS 문법
bash -n assets/hooks/*.sh              # Shell 문법
# JSON은 JSON.parse 또는 python -c "import json,sys;json.load(open(sys.argv[1]))" 로 확인
npm test                               # 전체 테스트
```

## 커밋 컨벤션

Conventional Commits를 따른다.

```
feat: 새 기능
fix: 버그 수정
docs: 문서
refactor: 리팩토링
test: 테스트
chore: 빌드·도구
```

예: `feat(generator): add qa-agent carving for vitest projects`

## PR 가이드

- PR은 작게 유지한다. 큰 재작성보다 리뷰 가능한 단위가 빠르게 머지된다.
- 문제·변경·검증 방법을 본문에 포함한다.
- 동작이 바뀌면 테스트를 추가·갱신한다.
- CLI 플래그·워크플로우·호환성이 바뀌면 `CHANGELOG.md`의 Unreleased에 항목을 추가한다.

> 본 가이드의 일부 규약은 OpenHarness CONTRIBUTING의 PR 원칙을 참고했다. 출처: https://github.com/HKUDS/OpenHarness/blob/main/CONTRIBUTING.md

## 보안

생성 자산에 secret·과도 권한·hook injection이 없도록 `auditor`를 통과시킨다. 외부 의존(URL·API)은 신중히 검토한다.

---

## 할루시네이션 검증 노트
- SKILL.md frontmatter 필수 필드·Progressive Disclosure는 공식 문서로 확인.
- 훅 exit code 2 차단, Squad 에이전트 규약은 프로젝트 내부 문서로 확인.
- 리포 URL(`claude-code-expert/carve-harness`)은 아직 생성 전일 수 있음 — 점유·생성 확인 필요(requirement.md OI-4).
