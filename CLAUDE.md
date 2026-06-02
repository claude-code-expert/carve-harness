# CLAUDE.md — carve-harness 개발 가이드

> 이 파일은 **carve-harness 리포 자체를 Claude Code로 개발할 때** 읽는 컨텍스트다.
> carve가 *생성하는* 대상 프로젝트의 CLAUDE.md가 아니다. (두 레이어 혼동 주의)


## Hallucination Guard

Before sending, self-verify:
- Do the referenced file paths / class names / method names actually exist?
- Are external links the correct domain/path? Is sample code syntactically valid?
- If unsure, mark it "needs verification" / "unverified" — do not guess.

## Language & Response Policy

| Target | Language |
|--------|----------|
| Internal reasoning & planning | English |
| Code, variable names, comments, logs, error messages | English |
| Git commit messages | English (Conventional Commits) |
| User-facing response (explanation · summary · question) | English summary → Korean conclusion (see format below) |

**Response format (always):**
- Write the working summary / explanation in **English first**.
- Then state the **final conclusion in Korean** (한글로 최종 결론).
- Order is fixed: **English summary → Korean conclusion**, each exactly once (see R2).
- When error output or quoted English text appears, add a brief Korean note for that part only.

**On task completion**, the Korean conclusion covers, in one block, once:
1. What changed (무엇을 변경했는지)
2. Why (왜 그렇게 했는지)
3. Caveats (주의할 점)


## 작업 원칙 (behavioral guidelines)

> LLM이 흔히 저지르는 실수를 줄이기 위한 행동 지침. 사소한 작업엔 판단껏, 비자명한 작업엔 속도보다 신중을 택한다.

### 1. 짜기 전에 생각한다

가정하지 말고, 혼란을 숨기지 말고, 트레이드오프를 드러낸다.

- 가정은 명시한다. 불확실하면 묻는다.
- 해석이 여럿이면 골라서 진행하지 말고 펼쳐 보인다.
- 더 단순한 방법이 있으면 말한다. 필요하면 반대한다.
- 불명확하면 멈춘다. 무엇이 혼란스러운지 짚고 묻는다.

### 2. 단순함이 먼저다

문제를 푸는 최소 코드. 투기적인 건 넣지 않는다.

- 요청 범위 밖 기능 금지.
- 일회성 코드에 추상화 금지.
- 요청 없는 "유연성"·"설정 가능성" 금지.
- 일어날 수 없는 시나리오용 에러 처리 금지.
- 200줄 짠 게 50줄로 되면 다시 짠다.
- 기준: "시니어 엔지니어가 과하다고 할까?" → 그렇다면 단순화.

### 3. 외과적 변경

건드려야 할 것만 건드리고, 내가 만든 흔적만 치운다.

- 인접 코드·주석·포맷을 "개선"하지 않는다.
- 멀쩡한 걸 리팩터링하지 않는다.
- 다르게 하고 싶어도 기존 스타일을 따른다.
- 무관한 죽은 코드는 언급만 하고 지우지 않는다.
- 내 변경으로 안 쓰이게 된 import·변수·함수만 제거한다. 기존 죽은 코드는 요청 없으면 둔다.
- 시험: 바뀐 모든 줄이 사용자 요청으로 직접 추적되어야 한다.

### 4. 목표 주도 실행

성공 기준을 정의하고, 검증될 때까지 반복한다.

- "검증 추가" → "잘못된 입력 테스트를 쓰고, 통과시킨다"
- "버그 수정" → "재현 테스트를 쓰고, 통과시킨다"
- "X 리팩터" → "전후로 테스트가 통과하는지 확인한다"
- 다단계 작업은 `단계 → 검증` 형식으로 짧은 계획을 먼저 밝힌다.

## 이 프로젝트가 하는 일

임의의 코드베이스를 분석해 맞춤 하네스(스킬·훅·커맨드·서브에이전트)를 자동 생성·설치하는 CLI(`carve`). 메타포는 **carve = 범용 자산을 프로젝트에 맞게 깎아냄** = 하네스 3기둥 중 "제약".

## 두 레이어 (절대 혼동 금지)

- **레이어 A** = carve-harness 리포 자체 (개발 대상). `src/`, `vendor/`, `assets/`
- **레이어 B** = carve가 대상 프로젝트에 까는 산출물. `<user-project>/.claude/`

코드를 짤 때 "지금 만지는 게 A인가 B의 템플릿인가"를 항상 분명히 한다.


> `vendor/`(openharness·subagents)는 분석·원본 소스였고 **삭제 대상**이다. 런타임 의존을 없애기 위해
> 필요한 자산(Squad·anti-slop)은 `assets/`로 녹여넣었다(100% melt-in). carve는 vendor 없이 동작한다.

## 개발 규칙 (이 리포의 flight-rules)

1. **vendor는 읽기 전용**: `vendor/` 내 파일을 직접 수정하지 않는다. 동기화는 submodule/subtree로만.
2. **syntax 검증 필수**: 생성/수정한 스크립트는 커밋 전 검증 — TS `tsc --noEmit`(`npm run check`), Shell `bash -n`, JSON `JSON.parse`.
   - 언어: TypeScript(ESM). Node ≥22.18 타입 스트리핑으로 **빌드 없이** `.ts` 직접 실행. `.ts` import는 확장자 명시(`'../src/cli.ts'`).
3. **멱등성**: 설치·생성은 재실행 시 사용자 수정 자산을 덮어쓰지 않는다. 충돌은 diff 제시 후 확인.
4. **생성 자산은 공식 포맷 준수**: SKILL.md는 `name`·`description` frontmatter 필수, Progressive Disclosure. 에이전트는 Squad 패턴(단일 책임·도구 권한 하드 제약).
5. **안전**: 생성 훅·커맨드에 secret 노출·과도 권한·hook injection이 없도록 audit을 통과시킨다.
6. **컨텍스트 절약**: 본 CLAUDE.md는 200줄 이하 유지. 상세는 `docs/`·`ARCHITECTURE.md`로 분리(Progressive Disclosure).

## 자산 생성 규약 (generator)

- 서브에이전트: frontmatter(`name`·`description`·`tools`·`model`·`maxTurns`) + 시스템 프롬프트(페르소나·절차·출력 형식)
- 스킬: SKILL.md 본문이 길면 `references/`로 분리
- 훅: 결정적 차단은 `PreToolUse`, 포맷·린트는 `PostToolUse`, 핸드오프는 `PreCompact`+`SessionStart`
- 커맨드: `/carve-*` 네이밍, `allowed-tools` 제한

## 자주 쓰는 명령

```bash
npm run check                    # TS 타입체크 (tsc --noEmit)
npm test                         # 단위 + E2E (node --test, .ts 직접 실행)
npm run test:cov                 # 커버리지 게이트 (≥80)
```

## Project-Specific References (extension slots)

Each project defines these in its own `.claude/rules/` and references them here:
@.claude/rules/project-structure.md
@.claude/rules/code-style.md
@.claude/rules/safety.md
@.claude/rules/gotchas.md

## Project-References

- Requirement: `requirement.md`
- Architecture: `ARCHITECTURE.md`
- Contributing: `CONTRIBUTING.md`
