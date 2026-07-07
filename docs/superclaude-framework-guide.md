# SuperClaude Framework — 하네스 활용 설치·사용법

> 저장소: https://github.com/SuperClaude-Org/SuperClaude_Framework (MIT, v4.3.0)
> 성격: Claude Code를 "구조화된 개발 플랫폼"으로 바꾸는 메타-설정 프레임워크
> 작성 2026-07-07 · 링크·버전 검증 완료(pypi 4.3.0, Python≥3.10)

---

## 0. 한 줄 요약 (결론 먼저)

SuperClaude는 **`/sc:` 네임스페이스 커맨드 30개 + 전문 에이전트 20개 + 행동 모드 7개 + 선택적 MCP 8개**를 한 번에 설치해, Claude Code에 **기획→구현→테스트→배포 전 주기 워크플로우**를 얹는 프레임워크다. 하네스의 "제약·피드백·상태"를 **커맨드/에이전트/모드로 패키징**한 형태로 볼 수 있다.

| 구성 | 수 | 역할 | 하네스 대응 |
|------|:--:|------|------------|
| Commands (`/sc:*`) | 30 | 개발 생명주기 슬래시 커맨드 | 워크플로우 |
| Agents (`@agent-*`) | 20 | 도메인 전문 서브에이전트 | 피드백(검증) |
| Modes | 7 | 상황별 자동 행동 전환 | 제약(행동 규칙) |
| MCP Servers | 8 | 리서치·문서 등 외부 연동(선택) | 상태·도구 |

---

## 1. 설치

### 방법 A — pipx (권장)
```bash
pipx install superclaude          # PyPI에서 설치 (v4.3.0, Python 3.10+)
superclaude install               # 30개 슬래시 커맨드 설치
superclaude mcp                   # (선택) MCP 서버 대화형 설치
superclaude doctor                # 설치 상태 점검
superclaude install --list        # 설치 가능 컴포넌트 목록
```

### 방법 B — npm
```bash
npm install -g @bifrost_inc/superclaude
superclaude install
```

### MCP만 선택 설치 (토큰 절감·속도)
```bash
superclaude mcp --list                          # 사용 가능 서버 목록
superclaude mcp --servers tavily context7        # 리서치(Tavily)·문서(Context7)만
```
> MCP 없이도 완전 동작(표준 성능). MCP 사용 시 실행 2~3배 빠르고 토큰 30~50% 절감(레포 주장 — 워크로드 의존).

---

## 2. 구성 요소 & 호출 방법

### 2.1 커맨드 (`/sc:*`) — 개발 생명주기 30종
| 단계 | 대표 커맨드 | 용도 |
|------|-----------|------|
| 발견 | `/sc:brainstorm` | 구조화된 아이디어 발굴 |
| 리서치 | `/sc:research` | 심층 웹 리서치(Tavily MCP 연동 시 강화) |
| 명세 | `/sc:spec-panel` · `/sc:design` | 명세·설계 (SDD와 연결) |
| 계획 | `/sc:workflow` · `/sc:task` · `/sc:estimate` | 워크플로우·작업 분해·추정 |
| 구현 | `/sc:implement` · `/sc:build` | 구현·빌드 |
| 검증 | `/sc:test` · `/sc:analyze` · `/sc:troubleshoot` | 테스트·분석·문제해결 |
| 개선 | `/sc:improve` · `/sc:cleanup` | 리팩토링·정리 |
| 관리 | `/sc:pm` · `/sc:git` · `/sc:document` | 프로젝트관리·git·문서 |
| 상태 | `/sc:load` · `/sc:save` · `/sc:reflect` | 세션 로드·저장·회고 |

전체: agent, analyze, brainstorm, build, business-panel, cleanup, design, document, estimate, explain, git, help, implement, improve, index, index-repo, load, pm, recommend, reflect, research, save, select-tool, spawn, spec-panel, task, test, troubleshoot, workflow

### 2.2 에이전트 (`@agent-*`) — 20종
- 호출: `@agent-security`, `@agent-frontend`, `@agent-architect`, `@agent-python-expert`, `@agent-refactoring-expert` 등
- 예: security-engineer · frontend-architect · performance-engineer · analyst

### 2.3 모드 (7종) — 자동 활성(행동 규칙)
| 모드 | 언제 | 효과 |
|------|------|------|
| Brainstorming | 요구가 모호할 때 | 대화형 발견 |
| Introspection | 추론 투명성 필요 | 메타인지 노출 |
| Deep Research | 조사 과제 | 체계적 웹 조사 |
| Task Management | 복잡·다단계 | 작업 조정 |
| Orchestration | 도구 선택 필요 | 지능형 도구 라우팅 |
| Token Efficiency | 컨텍스트 압박 | 압축 통신 |
| Standard | 기본 | 균형 |
> 모드는 `/sc:` 커맨드 사용 시 **작업 복잡도에 따라 자동 전환**된다(수동 지정 불필요).

---

## 3. 하네스 활용 시나리오 (활용법 + 예시)

- **기획→구현 파이프라인**: `/sc:brainstorm` (아이디어 구조화) → `/sc:spec-panel` (명세) → `/sc:workflow` (계획) → `/sc:implement` (구현) → `/sc:test` (검증). 예: "마크다운 에디터 만들기"를 브레인스토밍→명세→구현으로 한 줄기로 진행.
- **검증 게이트**: 구현 후 `@agent-security`로 시크릿·인가 점검, `/sc:analyze`로 품질 분석. 예: OAuth 로그인 구현 뒤 `@agent-security "state 파라미터·시크릿 노출 점검"`.
- **리서치 강화**: Deep Research 모드 + Tavily MCP로 `/sc:research "최신 배포 옵션"`. 예: 오라클 Always Free 배포법 조사.
- **토큰 관리**: Token Efficiency 모드 자동 활성으로 긴 세션 압축. `superclaude mcp`로 Context7 붙이면 문서 조회 토큰 절감.

---

## 4. 기존 하네스와의 관계

| 프레임워크 | 성격 | 겹침/차이 |
|-----------|------|----------|
| **SuperClaude** | pip 설치형 올인원(커맨드+에이전트+모드+MCP) | 정돈된 `/sc:` 네임스페이스 — 초보에 진입 쉬움 |
| ECC | 방대한 스킬·에이전트 생태계(271+) | 더 무겁고 세밀 — 선별 필요 |
| GSD | 경량 SDD 워크플로우 | `/sc:workflow`와 목적 중복 |
| mattpocock/skills | 작고 조합가능 스킬 | 철학 상반(프로세스 소유 vs 통제권) |

---

## 5. Devil's advocate

① **또 하나의 "프로세스 소유형" 프레임워크**다. `/sc:` 30개·모드 7개가 behavioral instruction으로 주입되면 **컨텍스트 토큰을 상시 소비**하고, GSD·ECC와 목적이 겹쳐 **동시 설치 시 충돌·혼란**이 생긴다 → 하나만 선택하거나 SuperClaude로 통일하는 게 안전. ② 초보 대상이면 30개 커맨드가 오히려 **선택 마비**를 부른다 → 강의는 `brainstorm·implement·test·git` 4~5개로 시작해 점진 확장 권장. ③ "2~3배 빠름·30~50% 토큰 절감"은 **레포 자체 주장**이라 워크로드별 실측 없이는 단정 금지.

---

## 6. 할루시네이션 / 출처 검증

| 항목 | 상태 | 근거 |
|------|:---:|------|
| v4.3.0 · 30 commands · 20 agents · 7 modes · 8 MCP | ✅ | README + pypi json 직접 확인 |
| 설치 `pipx install superclaude` → `superclaude install` | ✅ | README 설치 섹션 |
| npm `@bifrost_inc/superclaude` | ✅ | README(npmjs 403은 봇차단, 실제 정상) |
| 커맨드 29개 목록 | ✅ | docs/user-guide/commands.md 직접 추출 |
| 모드 7종·에이전트 호출(@agent-*) | ✅ | docs/user-guide/modes.md·agents.md |
| Python ≥ 3.10 | ✅ | pypi requires_python |
| MCP "2-3x 빠름·30-50% 토큰 절감" | ⚠️ 주장 | 레포 자체 수치 — 실측 아님 |
| 저장소·pypi·airis-gateway 링크 | ✅ | curl HTTP 200 |
| 각 커맨드 내부 동작 정합성 | ⚠️ | 채택 전 개별 커맨드 문서 확인 권장 |

**출처**: SuperClaude README(master), docs/user-guide/{commands,modes,agents}.md, PyPI(pypi.org/project/SuperClaude), Claude Code 공식 문서(code.claude.com/docs).

> ⚠️ Claude Code·SuperClaude 모두 버전 변동이 잦다. 도입 시 `superclaude doctor`·`superclaude install --list`로 현행 확인 권장.
