# carve-harness — 필수 기능·개념증명·구현 우선순위

> **분석 근거**: 프로젝트 내부 문서(HARNESS-ENGINEERING-LECTURE.md, harness-engineering-tutorial.md, 강의 목차 9.4 "나만의 하네스 만들기" 9-STEP)와 내부 git 링크 분석 — `HKUDS/OpenHarness`(베이스), `claude-code-expert/subagents`(Squad 자산), `affaan-m/everything-claude-code`(ECC 메타 레이어).
>
> | 항목 | 값 |
> |------|----|
> | 문서 버전 | v1.2 |
> | 작성일 | 2026-05-31 (v1.2 갱신 2026-06-05) |
> | 대상 | carve-harness 오픈소스 구현 |
>
> **v1.2 갱신**: v2.0 로드맵의 M8(라이프사이클 `update`/`diff`/`migrate`)·M9(분석 지능화: 모노레포·컨테이너 시그널·가중 스코어링)·M10(opt-in 로컬 텔레메트리 `carve report`)이 구현 완료됐다 ([MS7 로드맵](../milestones/MS7-v2-roadmap.md)).

---

## 결론 (먼저)

오픈소스로 "아무 프로젝트에서 하네스를 자동 구성"하려면, **개념증명(PoC)의 성패는 단 하나** — *"분석 → 슬롯 설계 → 깎기 → 검증 가능한 하네스 생성"의 1회 왕복이 실제로 도는가*다. 화려한 멀티 에이전트보다 **분석기·생성기·검증기 3개의 결정적 동작**이 먼저다.

| 구분 | 핵심 | 없으면 |
|------|------|--------|
| **MUST (PoC)** | analyzer · designer · generator · 검증 가능 산출물(flight-rules·evaluation-criteria·검증 훅) · 멱등 설치 | 제품이 성립 안 됨 |
| **SHOULD** | Evaluator 에이전트 · Sprint Contract · auditor · 멀티 에이전트 | 품질·신뢰가 약함 |
| **COULD** | 튜닝 루프 자동화 · 모델 라우팅 · 메일박스 코디네이터 · TUI | 있으면 좋음 |

---

## 1. 개념증명(PoC) — "이게 되면 프로젝트가 성립한다"

PoC의 단일 성공 기준은 다음 한 줄이 실제로 동작하는 것이다.

```
임의 프로젝트에서 "프로젝트에 맞는 하네스 구성해줘"
  → analyzer가 스택을 맞게 감지하고
  → generator가 .claude/에 깎인 자산을 생성하며
  → 생성된 검증 훅이 실제로 위반을 차단한다 (결정적)
```

**검증 시나리오 (PoC 합격 조건):**
1. Next.js+TS 프로젝트에서 트리거 → `evaluator` 에이전트 + `any` 금지 flight-rule + PostToolUse 린트 훅 생성
2. 생성된 PreToolUse 훅이 `rm -rf` 같은 위험 커맨드를 exit code 2로 실제 차단
3. 같은 명령 재실행 시 사용자 수정 자산을 덮어쓰지 않음(멱등)
4. auditor가 생성물에서 secret 노출·과도 권한 0건 확인

> **핵심 원칙 (검증된 인용)**: "하네스의 모든 컴포넌트는 '모델이 혼자 못 하는 것'에 대한 가정을 인코딩한다. 그 가정은 항상 검증해야 한다." — Anthropic Harness design. carve-harness는 이 가정을 **프로젝트 분석으로 자동 추론**하는 도구다.

---

## 2. 필수 기능 (MUST) — MVP 구성요소

각 기능은 OpenHarness 분류 체계와 강의 9-STEP에 근거한다.

### M1. Analyzer — 프로젝트 도메인 분석
- **무엇**: 언어·프레임워크·테스트러너·CI·패키지매니저·모노레포·디렉토리 구조 감지 (읽기 전용)
- **왜 필수**: 무엇을 깎을지 결정하는 입력. 이게 없으면 "맞춤"이 불가능
- **사용법**: 트리거 시 자동 1단계 실행 → `analysis-report.json`(메모리)
- **PoC 범위**: package.json / tsconfig / lockfile / .github 존재만으로 80% 추론

### M2. Designer — 하네스 슬롯 설계
- **무엇**: OpenHarness 10서브시스템(engine·tools·skills·plugins·permissions·hooks·commands·mcp·memory·coordinator)을 슬롯 후보로 두고 프로젝트에 필요한 것만 매핑
- **왜 필수**: 분류 체계가 곧 "받을 것/안 받을 것"의 기준 (강의 STEP 1)
- **사용법**: analyzer 리포트 → 슬롯 설계안. 예) 테스트러너 발견 → `qa` 에이전트 + 테스트 검증 훅 슬롯

### M3. Generator — 자산 깎기·생성
- **무엇**: `vendor/subagents`(Squad)·`assets/` 베이스에서 선별 → 프로젝트 컨벤션에 맞게 잘라 `.claude/`에 생성
- **왜 필수**: carve의 핵심 동작. 4종 산출물(agent·skill·command·hook) 생성
- **사용법**: 슬롯 설계안 → `.claude/agents|skills|commands|hooks/` + `settings.json` 훅 등록

### M4. 평가 기준 생성 — evaluation-criteria.md
- **무엇**: 프로젝트 품질 기준을 측정 가능한 항목으로 생성 (기능 완성도·타입 안전성·보안·테스트)
- **왜 필수**: "좋은 결과"를 주관에 두지 않는다 — 하네스 1순위 원칙 (강의 STEP 1)
- **사용법**: 가중치(★) 포함 체크리스트 자동 생성. MUST PASS / SHOULD PASS 구분

### M5. 제약 생성 — flight-rules.md + 검증 훅
- **무엇**: 금지/필수 규칙(`any` 금지, SQL 파라미터 바인딩 필수 등) + PreToolUse(차단)·PostToolUse(린트) 훅
- **왜 필수**: 하네스 3기둥 중 "제약". **exit code 2가 유일한 결정적 차단 수단** (강의 STEP 7)
- **사용법**: 생성 훅이 `.claude/settings.json`에 자동 등록되어 실시간 작동

### M6. 멱등 설치 (installer)
- **무엇**: 재실행 시 사용자 수정 자산 비파괴 병합, `.bak` 보존, jq 기반 settings.json 안전 갱신
- **왜 필수**: Squad install.sh가 이미 검증한 패턴. 덮어쓰면 신뢰 붕괴
- **사용법**: `carve install` / 재실행 시 충돌은 diff 제시 후 확인

### M7. CLI 엔트리포인트 + 자연어 트리거
- **무엇**: `carve` 바이너리(npm `bin`) + `harness-architect` 스킬(자연어 "하네스 구성해줘" 트리거)
- **왜 필수**: 진입점. Squad의 `bin/` + SKILL.md `description` 자동 트리거 패턴 차용
- **사용법**: `npm i -g carve-harness` → `carve install` → 세션에서 자연어 트리거

---

## 3. 서브 기능 (SHOULD / COULD) — 구현 우선순위 랭킹

> 평가축: **(영향도 × 차별성) ÷ 구현난이도**. PoC 직후 순서대로 쌓는다.

| 순위 | 기능 | 분류 | 영향 | 난이도 | 근거·비고 |
|:---:|------|:---:|:---:|:---:|------|
| **1** | **Evaluator 서브에이전트** | SHOULD | ★★★★★ | 中 | Self-Eval Blindspot 대응. Generator와 분리된 까다로운 QA. 하네스 핵심 (강의 STEP 6) |
| **2** | **Sprint Contract 생성** | SHOULD | ★★★★☆ | 低 | 코딩 전 "완료" 합의 → Evaluator가 정확히 어디를 볼지 안다. 템플릿만 생성 (STEP 5) |
| **3** | **auditor 자기 검증** | SHOULD | ★★★★☆ | 中 | 생성물 보안 스캔(secret·권한·hook injection·MCP·agent config). ECC AgentShield 패턴 차용 |
| **4** | **결정적 검증 훅 강화** | SHOULD | ★★★★☆ | 低 | shellcheck·tsc·grep 기반 PostToolUse. ralph 등 공식 검증 플러그인 연동 |
| **5** | **멀티 에이전트 — 3에이전트 병렬** | COULD | ★★★★☆ | 中 | 백엔드·프론트·테스트 병렬(Planner→Generator⇄Evaluator). 대형 작업에서 효과 (강의 9.5.1) |
| **6** | **Evaluator 튜닝 루프 지원** | COULD | ★★★★☆ | 中 | 로그에서 오판 사례 수집 → few-shot 자동 추가 보조. 1~2주 운영 도구 (STEP 6) |
| **7** | **모델 3-Tier 라우팅** | COULD | ★★★☆☆ | 中 | 역할별 Opus/Sonnet/Haiku 분배 자동 제안. 비용 최적화 (강의 9.1.3) |
| **8** | **COORDINATOR_MODE 메일박스** | COULD | ★★★☆☆ | 高 | 에이전트 간 직접 통신(TeamCreate). 복잡도 높아 후순위 (강의 9.5.2) |
| **9** | **Handoff/Changelog 자동화** | COULD | ★★★☆☆ | 低 | PreCompact+SessionStart 훅으로 세션 인계. 상태관리 기둥 보강 (강의 3.7.3) |
| **10** | **harness-audit 메타 커맨드** | COULD | ★★★☆☆ | 中 | 구성된 하네스 자체를 점검하는 `/harness-audit`. ECC 메타 레이어 차용 |
| **11** | **모델 비종속(provider) 추상화** | COULD | ★★★☆☆ | 高 | Claude/GPT/Kimi/Ollama 백엔드 교체. OpenHarness가 이미 강점 — 차용 검토 |
| **12** | **TUI / 진행 시각화** | COULD | ★★☆☆☆ | 高 | 생성 과정 시각화. 가치 대비 비용 높음. 최후순위 |

### 우선순위 요약 (구현 로드맵)
```
PoC (M1~M7)                     ← 여기까지 되면 "오픈소스 성립"
  └─▶ 1~4 (Evaluator·Contract·auditor·검증훅)   ← 품질·신뢰 확보 (v0.2)
        └─▶ 5~7 (멀티에이전트·튜닝·라우팅)        ← 확장·최적화 (v0.3)
              └─▶ 8~12 (코디네이터·메타·provider·TUI)  ← 고도화 (v0.4+)
```

---

## 4. 사용법 (PoC 기준 전체 흐름)

```bash
# 1. 설치
npm i -g carve-harness          # 전역 설치 (M7)
cd <your-project>
carve install                   # 부트스트랩 자산 설치 (M6)

# 2. 자연어 트리거 (Claude Code 세션)
#   "프로젝트에 맞는 하네스 구성해줘"
#   → M1 분석 → M2 설계 → M3 생성 → M4·M5 제약/평가 → auditor 검증

# 3. 결과 확인
ls .claude/agents .claude/skills .claude/commands .claude/hooks
cat flight-rules.md evaluation-criteria.md

# 4. 작동 검증 (PoC 합격 조건)
#   - 위험 커맨드 시도 → PreToolUse 훅이 차단 (exit code 2)
#   - 파일 수정 → PostToolUse 린트 훅 자동 실행
```

> **활용 팁**: 단순 CRUD 프로젝트엔 Evaluator 없이 Generator+검증 훅만으로 충분하고, 복잡한 멀티기능 앱엔 3에이전트 풀 하네스를 권장한다. carve의 designer가 프로젝트 복잡도를 보고 **하네스 수준을 자동 제안**하게 하는 것이 차별점이다. (강의: 단일 $9 vs 풀 하네스 $200 — 태스크 중요도로 조정)

---

## 5. 분석한 내부 git 링크 (출처)

| 링크 | 역할 | 본 문서 반영 |
|------|------|-------------|
| https://github.com/HKUDS/OpenHarness | 베이스 하네스 (10서브시스템·4확장점) | M2 슬롯 설계 기준, #11 provider 추상화 |
| https://github.com/claude-code-expert/subagents | Squad 자산·CLI 설치 패턴 | M3 자산 소스, M6 멱등 설치, M7 CLI |
| https://github.com/affaan-m/everything-claude-code | ECC 메타 레이어·AgentShield | #3 auditor, #10 harness-audit |
| https://github.com/gsd-build/get-shit-done | Context Rot 대응·스펙 주도 | M4 평가기준, #2 Sprint Contract |

### 외부 1차 출처
- Anthropic Harness design: https://www.anthropic.com/engineering/harness-design-long-running-apps
- Agent Skills: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview

---

## 6. 할루시네이션 검증 노트

- **검증됨 (내부 문서·git 원문 교차)**:
  - OpenHarness 10서브시스템·4확장점, Squad 8커맨드·install.sh 멱등 패턴(.bak 보존·jq 등록)·145 테스트: 내부 문서(7.1.x)·README 원문
  - 하네스 3기둥, Self-Eval Blindspot, Sprint Contract, Evaluator 튜닝, 평가기준 가중치, 단일 vs 풀 하네스 비용($9/$200/$124): 강의 문서·Anthropic 글
  - ECC AgentShield 5카테고리 스캔, 28 subagents/119 skills: 큐레이션 문서
- **미검증 (확정 전 확인 필요)**:
  - 각 git 링크의 라이선스 재배포 조건 (requirement.md OI-2)
  - ECC star 수 등 수치는 조회 시점(2026-04)·출처별 변동 — 단정 회피
  - 우선순위 랭킹의 "난이도/영향" 평가는 설계 판단이며, 실제 구현 중 재조정 필요
- **버전 주의**: hook 이벤트 수·커맨드 수는 Claude Code 버전에 따라 변동 → 구현 시점 CHANGELOG 재확인 권장
