# 하네스 구성요소 단위 테스트 가이드

> 각 하네스 구성요소(훅·스킬·서브에이전트·커맨드·파이프라인)를 **결정적으로** 검증하는 방법.
> 개별 실행용 스크립트는 `scripts/`에 있다.

## 빠른 시작 — 개별 스크립트

```bash
bash scripts/test-hooks.sh      # 훅: stdin JSON → exit code
bash scripts/test-antislop.sh   # anti-slop: check-slop.mjs → exit 1/0
bash scripts/test-squad.sh      # Squad 라우터: 키워드 → 위임 에이전트 (jq 필요)
bash scripts/test-install.sh    # 설치 파이프라인: install→doctor→멱등→uninstall
bash scripts/test-all.sh        # 위 전체 + npm test + 6축 벤치
```

각 스크립트는 `PASS/FAIL`을 출력하고, 실패가 있으면 비-0으로 종료한다.

## 전체 게이트

```bash
npm run check       # 타입체크 (tsc --noEmit)
npm test            # 단위 + E2E (node --test, 96개)
npm run test:cov    # 커버리지 게이트 (>=80)
node bench/run.mjs  # 6축 정량 점수 (제어/안전·라우팅·기능·구성 실측)
```

## 구성요소별 방법

### 1. 훅 (Hook)
계약 = **Claude Code가 stdin으로 주는 JSON → 종료 코드**. 위험=2(차단), 안전=0.

```bash
echo '{"tool_input":{"command":"rm -rf /"}}' | bash assets/hooks/block-destructive.sh; echo $?  # 2
echo '{"tool_input":{"file_path":".env"}}'   | bash assets/hooks/protect-secrets.sh;  echo $?  # 2
# 린트/테스트 훅은 명령을 env로 주입
echo '{"tool_input":{"command":"git commit -m x"}}' | CARVE_LINT_CMD=false bash assets/hooks/pre-commit-lint.sh; echo $?  # 2
bash -n assets/hooks/*.sh   # 문법
```
자동화: `test/unit/hooks.test.ts` · 스크립트: `scripts/test-hooks.sh`.

### 2. 스킬 (Skill)
- frontmatter(`name`·`description`) 유효성 확인: `head -10 assets/skills/<id>/SKILL.md`
- 트리거: 세션에서 자연어 발화 확인(예: "커밋 메시지 만들어" → commit 스킬).
- anti-slop 스킬은 결정적 린터로 게이트:
```bash
node .claude/skills/clean-html/scripts/check-slop.mjs page.html   # exit 1=위반, 0=clean
```
자동화: `test/unit/check-slop.test.ts` · 스크립트: `scripts/test-antislop.sh`.

### 3. 서브에이전트 (Squad)
```bash
echo '{"prompt":"보안 취약점 점검"}' | bash assets/squad/hooks/squad-router.sh | grep -o 'squad-[a-z]*'  # squad-audit
head -12 assets/squad/agents/squad-review.md   # tools 권한 하드 제약 확인
```
스크립트: `scripts/test-squad.sh` (jq 필요). 벤치 축 3이 8종 일괄 측정.

### 4. 커맨드 shim
```bash
head -5 assets/commands/carve-commit.md   # description, allowed-tools 제한
```

### 5. 파이프라인 + 설치 (analyzer~installer)
```bash
T=$(mktemp -d); printf '{"name":"x","dependencies":{"react":"^19"}}' > "$T/package.json"
node bin/carve.ts install "$T" --only commit,block-destructive   # 선택 설치
node bin/carve.ts doctor "$T"                                    # 점검
node bin/carve.ts install "$T" --only commit,block-destructive   # 재설치=멱등
node bin/carve.ts uninstall "$T"; rm -rf "$T"                    # 클린 제거
```
자동화: `test/e2e/installer.e2e.test.ts`·`poc.e2e.test.ts` · 스크립트: `scripts/test-install.sh`.

## 새 구성요소 추가 시 (기능마다 테스트 1개)

| 구성요소 | 테스트 파일 | 패턴 |
|----------|------------|------|
| 훅 | `test/unit/hooks.test.ts` | `spawnSync('bash',[hook],{input:JSON})` → `status` |
| 스킬 린터 | `test/unit/check-slop.test.ts` | 슬롭/클린 fixture → exit 1/0 |
| analyzer | `test/unit/analyzer.test.ts` | fixture → ProjectProfile |
| catalog/designer | `test/unit/designer.test.ts` | 점수·추천 셋 |
| generator | `test/unit/generator.test.ts` | artifact 경로·치환 |
| auditor | `test/unit/auditor.test.ts` | secret/권한 시드 → finding |
| 설치 | `test/e2e/*.e2e.test.ts` | 임시 디렉토리 왕복 |

원칙: **결정적 입력 → 관측 가능한 출력(exit code / 생성 파일 / 반환 객체)을 단언**. fixture는 `test/fixtures/`.
