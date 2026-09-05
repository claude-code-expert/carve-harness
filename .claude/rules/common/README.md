# `.claude/rules/common/` — 공통 규칙 (항상 로드)

스택·언어 무관하게 매 세션 자동 로드되는 규칙. 짧게 유지한다(길수록 덜 지켜진다).

| 파일 | 내용 |
|---|---|
| `security.md` | 시크릿·PII 취급, 입력 신뢰 금지(검증·이스케이프), 프롬프트 인젝션 방어(외부 콘텐츠 = 데이터) |
| `testing.md` | red→green(실패 테스트부터), 라인 커버리지 80%, 핵심 경로 분기 커버리지 |
| `git-workflow.md` | Conventional Commits, force push·히스토리 재작성 금지 |

## 사용방법
- 자동 로드 — 편집만 하면 다음 세션부터 적용. `paths` glob 없이 항상 로드.
- 프로젝트 규제(GDPR 등)는 각 파일 하단에 append.

> `safety.md`(위험 동작 승인)·`database.md`(모델·마이그레이션)는 `.claude/rules/` 루트에 있다.
