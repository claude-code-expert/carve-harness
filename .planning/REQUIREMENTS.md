# REQUIREMENTS — Claude 하네스 템플릿 하드닝 (v1)

> 출처: `.planning/codebase/CONCERNS.md` + `.planning/research/SUMMARY.md`(4-dimension 리서치).
> Core Value: **게이트가 실제로 작동**. 강제 누수 제거 우선.

## v1 Requirements

### GUARD — 제약 기둥 강제 (constraints)

- [ ] **GUARD-01**: 가드 훅은 `jq` 부재 또는 JSON 파싱 실패 시 fail-closed로 차단(exit 2)한다 (현재 fail-open: 파싱 실패→전부 허용)
- [ ] **GUARD-02**: 가드 매처가 `Write|Edit|MultiEdit|NotebookEdit` 전 쓰기 도구를 포착한다
- [ ] **GUARD-03**: Bash 쓰기 명령(`echo >`, `cp`, `sed -i`, `tee` 등)이 보호 경로를 대상으로 하면 차단한다 (`.tool_input.command` 검사)
- [ ] **GUARD-04**: 파일 내용의 하드코딩 시크릿(AKIA/sk-/ghp-/PEM/JWT 패턴)을 감지하면 쓰기를 차단한다

### GATE — 피드백/검증 게이트 (feedback)

- [ ] **GATE-01**: Stop 게이트가 `stop_hook_active`를 확인해 무한 continuation 루프를 방지한다
- [ ] **GATE-02**: Stop 게이트가 훅 타임아웃(기본 60s)으로 조용히 무력화되지 않도록 인지·대응한다
- [ ] **GATE-03**: Stop 검증이 변경된 모듈만 대상으로 증분 실행된다 (매 Stop 풀빌드 회피)

### OBS — 관측성 (observability, 키스톤)

- [ ] **OBS-01**: 훅 이벤트를 구조화 JSONL로 `logs/`에 append한다 (Bash+jq, 런타임 의존성 없음)
- [ ] **OBS-02**: 포맷 훅 실패(포맷터 미설치·오류)가 JSONL에 기록돼 가시화된다 (C8)

### STATE — 상태 기둥 (state)

- [x] **STATE-01**: 핸드오프가 실제 미완료 TODO·다음 단계·핵심 결정을 수집한다 (하드코딩 `[내용없음]` 제거, C7)
- [x] **STATE-02**: `SessionEnd` 훅으로 정상 종료 시에도 핸드오프를 저장한다
- [x] **STATE-03**: `specs/DECISIONS.md` 결정 기록이 핸드오프 출력에 반영된다

### AUDIT — 자가 감사

- [x] **AUDIT-01**: `/harness-audit`가 jq 존재·훅 등록·스크립트 실행권한(+x)·`bash -n`을 PASS/FAIL로 판정한다
- [x] **AUDIT-02**: `/harness-audit`가 매처 커버리지(전 쓰기 도구 + Bash-write)를 검증한다
- [x] **AUDIT-03**: `/harness-audit`가 각 `rules/*` 정책이 강제 게이트에 매핑되는지 점검하고 `[내용없음]` 핸드오프를 거부한다

### CFG — 규칙·설정

- [ ] **CFG-01**: 크리티컬 규칙을 always-on 규칙(`paths:` 없음)으로 전환한다 (압축 후 자동 재주입 — CLAUDE.md 중복 불필요, C10)
- [ ] **CFG-02**: 훅 경로를 `${CLAUDE_PROJECT_DIR}` 기준으로 참조한다 (서브디렉토리·모노레포 안전)
- [ ] **CFG-03**: 부작용 커맨드(`commit`)에 `disable-model-invocation: true`를 설정한다
- [ ] **CFG-04**: `settings.json`에 `"$schema"`를 추가한다 (버전 드리프트 조기 감지)
- [ ] **CFG-05**: 남은 스텁(`specs/README`·java/react `[추가 규칙]`·스킬 본문)을 범용 기본값으로 채운다

### HYG — 위생

- [ ] **HYG-01**: `install.md`에 설치 절차를 작성한다 (또는 삭제, C1)
- [ ] **HYG-02**: `.gitignore`(루트 `.env*` 차단 포함) + `LICENSE`를 추가한다 (C11)
- [ ] **HYG-03**: 매뉴얼의 `docs.claude.com` 링크를 `code.claude.com`으로 갱신한다

## v2 / Deferred

(없음 — 사용자가 전 항목 v1 선택)

## Out of Scope

- 특정 프로덕트 도메인 규칙 하드코딩 — 범용 템플릿 유지
- 새 스택(Python·Go 등) 규칙·훅 — 후속 마일스톤
- CI/CD 파이프라인 통합 — 하네스는 로컬 훅 계층
- 시크릿 Bash **읽기** 완전차단 — deny-list best-effort로 충분(근본은 `.gitignore .env*` + 규칙). GUARD-04는 **쓰기/커밋** 시 내용 스캔이라 별개
- 런타임 무거운 관측성(OpenTelemetry/SIEM/대시보드/TTS) — JSONL로 대체

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| GUARD-01 | Phase 1 | Pending |
| GUARD-02 | Phase 1 | Pending |
| GUARD-03 | Phase 1 | Pending |
| GATE-01 | Phase 1 | Pending |
| GATE-02 | Phase 1 | Pending |
| CFG-01 | Phase 1 | Pending |
| CFG-02 | Phase 1 | Pending |
| CFG-03 | Phase 1 | Pending |
| CFG-04 | Phase 1 | Pending |
| OBS-01 | Phase 2 | Pending |
| OBS-02 | Phase 2 | Pending |
| STATE-01 | Phase 3 | Complete |
| STATE-02 | Phase 3 | Complete |
| STATE-03 | Phase 3 | Complete |
| AUDIT-01 | Phase 4 | Complete |
| AUDIT-02 | Phase 4 | Complete |
| AUDIT-03 | Phase 4 | Complete |
| GUARD-04 | Phase 5 | Pending |
| GATE-03 | Phase 5 | Pending |
| CFG-05 | Phase 5 | Pending |
| HYG-01 | Phase 5 | Pending |
| HYG-02 | Phase 5 | Pending |
| HYG-03 | Phase 5 | Pending |

**Coverage:** 23/23 v1 requirements mapped — no orphans, no duplicates.

---
*Last updated: 2026-07-06 after roadmap traceability mapping*
