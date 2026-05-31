# Squad Router - Verified Keywords

> Tested against `squad-router-poc.sh` on Claude Code v2.1.89
> All keywords below passed matching tests with 100% hit rate and 0% false positives.

---

## Keyword Selection Criteria

1. **Hit rate** — keyword must reliably trigger the correct agent
2. **False positive resistance** — must not trigger on unrelated prompts
3. **Conflict safety** — multi-word patterns resolve ambiguity before single-word matching

---

## Phase 2: Conflict Resolution Patterns (checked first)

These multi-word patterns are matched BEFORE any single-word keyword to resolve ambiguity.

| Prompt Pattern | Routed To | Instead Of | Reason |
|----------------|-----------|------------|--------|
| `pr 리뷰`, `pr review`, `테스트 코드 리뷰` | **squad-review** | squad-gitops | "리뷰" is the intent |
| `pr 작성`, `pr 만들`, `pr 써` | **squad-gitops** | squad-review | "작성/만들" is the intent |
| `보안 리뷰`, `보안 검토`, `security review` | **squad-audit** | squad-review | "보안" is the intent |
| `에러 테스트`, `빌드 에러`, `build error` | **squad-debug** | squad-qa | "에러" is the intent |
| `빌드 확인`, `빌드 돌`, `build check` | **squad-qa** | squad-debug | "확인/돌려" = verification |
| `코드 정리`, `code cleanup` | **squad-refactor** | squad-review | "정리" = refactoring |

---

## Phase 3: Single Keyword Matching (priority order)

### Priority 1: squad-audit (Security)

| Keyword | Lang | Hit Rate | Example Prompt |
|---------|------|----------|----------------|
| `보안` | KR | 100% | "보안 검사해줘" |
| `security` | EN | 100% | "security check" |
| `취약점` | KR | 100% | "취약점 스캔해" |
| `vulnerab` | EN | 100% | "vulnerability scan" |
| `audit` | EN | 100% | "audit this code" |
| `owasp` | EN | 100% | "OWASP 체크해" |
| `시크릿` | KR | 100% | "시크릿 노출 확인" |
| `secret` | EN | 100% | "check for secrets" |
| `인젝션` | KR | 100% | "인젝션 취약점" |
| `injection` | EN | 100% | "SQL injection check" |
| `xss` | EN | 100% | "XSS 방어 확인" |
| `csrf` | EN | 100% | "CSRF 보호 확인" |

**Total: 12 keywords (6 KR / 6 EN)**

---

### Priority 2: squad-debug (Error/Bug)

| Keyword | Lang | Hit Rate | Example Prompt |
|---------|------|----------|----------------|
| `디버그` | KR | 100% | "디버그 해줘" |
| `debug` | EN | 100% | "debug this issue" |
| `에러` | KR | 100% | "에러가 나요" |
| `error` | EN | 100% | "error occurred" |
| `버그` | KR | 100% | "버그가 있어" |
| `bug` | EN | 100% | "found a bug here" |
| `오류` | KR | 100% | "오류가 발생했어" |
| `크래시` | KR | 100% | "크래시가 났어" |
| `crash` | EN | 100% | "it crashed" |
| `stack trace` | EN | 100% | "check the stack trace" |
| `traceback` | EN | 100% | "traceback shows this" |
| `exception` | EN | 100% | "exception thrown" |

**Total: 12 keywords (5 KR / 7 EN)**

---

### Priority 3: squad-plan (Planning)

| Keyword | Lang | Hit Rate | Example Prompt |
|---------|------|----------|----------------|
| `기획` | KR | 100% | "이 기능 기획해줘" |
| `plan ` (trailing space) | EN | 100% | "plan the new feature" |
| `설계해` | KR | 100% | "설계해 주세요" |
| `와이어프레임` | KR | 100% | "와이어프레임 그려줘" |
| `wireframe` | EN | 100% | "wireframe the dashboard" |
| `유저스토리` | KR | 100% | "유저스토리 작성해" |
| `user story` | EN | 100% | "user story for login" |
| `브레인스토밍` | KR | 100% | "브레인스토밍 하자" |
| `brainstorm` | EN | 100% | "brainstorm ideas" |
| `스펙` | KR | 100% | "스펙 작성해줘" |
| `spec` | EN | 100% | "write a spec for this" |
| `요구사항` | KR | 100% | "요구사항 정리해줘" |
| `구현 계획` | KR | 100% | "구현 계획 세워줘" |

**Total: 13 keywords (8 KR / 5 EN)**

---

### Priority 4: squad-refactor (Refactoring)

| Keyword | Lang | Hit Rate | Example Prompt |
|---------|------|----------|----------------|
| `리팩토링` | KR | 100% | "이 코드 리팩토링해줘" |
| `리팩터` | KR | 100% | "리팩터링 부탁" |
| `refactor` | EN | 100% | "refactor this module" |
| `클린업` | KR | 100% | "클린업 해줘" |
| `cleanup` | EN | 100% | "cleanup the utils" |
| `clean up` | EN | 100% | "clean up this mess" |
| `추출` | KR | 100% | "함수 추출해줘" |
| `extract` | EN | 100% | "extract this function" |
| `중복 제거` | KR | 100% | "중복 제거해줘" |
| `코드 개선` | KR | 100% | "코드 개선해줘" |
| `함수 분리` | KR | 100% | "함수 분리해줘" |
| `컴포넌트 분리` | KR | 100% | "컴포넌트 분리해" |

**Total: 12 keywords (7 KR / 5 EN)**

---

### Priority 5: squad-docs (Documentation)

| Keyword | Lang | Hit Rate | Example Prompt |
|---------|------|----------|----------------|
| `문서` | KR | 100% | "문서 작성해줘" |
| `document` | EN | 100% | "document this API" |
| `readme` | EN | 100% | "README 업데이트해" |
| `리드미` | KR | 100% | "리드미 갱신해줘" |
| `jsdoc` | EN | 100% | "JSDoc 달아줘" |
| `tsdoc` | EN | 100% | "TSDoc 추가해" |
| `주석` | KR | 100% | "주석 달아줘" |
| `comment` | EN | 100% | "add comments here" |
| `문서화` | KR | 100% | "문서화 해줘" |

**Total: 9 keywords (4 KR / 5 EN)**

---

### Priority 6: squad-gitops (Git Operations)

| Keyword | Lang | Hit Rate | Example Prompt |
|---------|------|----------|----------------|
| `커밋` | KR | 100% | "커밋 메시지 작성해" |
| `commit` | EN | 100% | "write a commit message" |
| `체인지로그` | KR | 100% | "체인지로그 갱신해" |
| `changelog` | EN | 100% | "update the changelog" |
| `릴리즈 노트` | KR | 100% | "릴리즈 노트 작성해" |
| `release note` | EN | 100% | "write release notes" |
| `conventional` | EN | 100% | "conventional commit format" |

**Total: 7 keywords (3 KR / 4 EN)**

---

### Priority 7: squad-qa (Testing/QA)

| Keyword | Lang | Hit Rate | Example Prompt |
|---------|------|----------|----------------|
| `테스트` | KR | 100% | "테스트 돌려줘" |
| `test` | EN | 100% | "test this feature" |
| `qa` | EN | 100% | "QA 진행해" |
| `검증` | KR | 100% | "검증해줘" |
| `린트` | KR | 100% | "린트 돌려" |
| `lint` | EN | 100% | "lint check please" |
| `타입체크` | KR | 100% | "타입체크 해줘" |
| `type check` | EN | 100% | "type check please" |
| `리그레션` | KR | 100% | "리그레션 확인해" |
| `regression` | EN | 100% | "regression test needed" |

**Total: 10 keywords (5 KR / 5 EN)**

---

### Priority 8: squad-review (Code Review — broadest, matched last)

| Keyword | Lang | Hit Rate | Example Prompt |
|---------|------|----------|----------------|
| `리뷰` | KR | 100% | "이 코드 리뷰해줘" |
| `review` | EN | 100% | "review this code" |
| `코드 검토` | KR | 100% | "코드 검토해줘" |
| `검토해` | KR | 100% | "검토해 주세요" |
| `diff 봐` | KR | 100% | "diff 봐줘" |

**Total: 5 keywords (4 KR / 1 EN)**

---

## Summary

| Agent | Priority | Keywords | KR | EN | Hit Rate | FP Rate |
|-------|----------|----------|----|----|----------|---------|
| squad-audit | 1 (highest) | 12 | 6 | 6 | 100% | 0% |
| squad-debug | 2 | 12 | 5 | 7 | 100% | 0% |
| squad-plan | 3 | 13 | 8 | 5 | 100% | 0% |
| squad-refactor | 4 | 12 | 7 | 5 | 100% | 0% |
| squad-docs | 5 | 9 | 4 | 5 | 100% | 0% |
| squad-gitops | 6 | 7 | 3 | 4 | 100% | 0% |
| squad-qa | 7 | 10 | 5 | 5 | 100% | 0% |
| squad-review | 8 (lowest) | 5 | 4 | 1 | 100% | 0% |
| **Total** | | **80** | **42** | **38** | **100%** | **0%** |

Plus 6 conflict resolution patterns (12 trigger phrases) and 2 opt-out mechanisms (`--no-route`, `SQUAD_ROUTER=off`).

---

## Excluded Keywords (and why)

| Keyword | Would Match | Excluded Because |
|---------|-------------|------------------|
| `docs` | squad-docs | 3 chars, path name false positives ("docs/") |
| `dry` | squad-refactor | 3 chars, common English word |
| `fail`, `실패` | squad-debug | Too broad, "test failed" ≠ "debug this" |
| `안돼`, `안되` | squad-debug | Extremely common in casual Korean |
| `정리해` | squad-refactor | Too generic ("정리해" can mean many things) |
| `verify` | squad-qa | General purpose, not QA-specific |
| `pull request` | squad-gitops | Conflicts with "PR review" → squad-review |
| `피알`, `풀리퀘` | squad-gitops | Slang abbreviations, false positive risk |
| `코드 확인`, `코드 체크` | squad-review | Too generic, could mean anything |
| `planning` | squad-plan | Redundant with "plan " |
| `돌려`, `통과` | squad-qa | Generic verbs used in many contexts |

---

## Opt-out Mechanisms

| Method | Scope | Example |
|--------|-------|---------|
| `--no-route` in prompt | Per-prompt | "리뷰해줘 --no-route" |
| `#direct` in prompt | Per-prompt | "#direct 에러 봐줘" |
| `SQUAD_ROUTER=off` env | Global | Disables all routing |
| `/squad-*` slash command | Automatic | Slash commands skip routing |

---

## Test Results

```
Date:    2026-04-01
Version: Claude Code v2.1.89
Tests:   112 total
Pass:    112 (100%)
Fail:    0 (0%)

Breakdown:
  - 8 agent keyword tests:     80/80  ✅
  - Conflict resolution tests: 15/15  ✅
  - False positive tests:      10/10  ✅ (all correctly rejected)
  - Skip/opt-out tests:         5/5   ✅
  - Case insensitivity:         2/2   ✅
```
