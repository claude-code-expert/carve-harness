# 하네스 설치 리스트 (Claude Code 실행용)

> 각 자산의 용도·설치 주소·설치 명령·호출 방법. Claude Code가 이 문서를 읽고 순서대로 설치·호출.
> 대상: 개발 시작 단계 학습자 (필수부터, 271개 전체설치 금지)
> 작성 2026-06-26 · 모든 저장소 HTTP 200 검증 · README 근거

---

## A. 스킬 세트 — mattpocock/skills (기본, 작고 조합가능)

- 용도: TDD·PRD·구현·리뷰·버그진단·핸드오프 등 엔지니어링 실무 스킬 37종
- 저장소: https://github.com/mattpocock/skills (MIT)
- 설치:
```bash
npx skills@latest add mattpocock/skills
# 대화형 선택 → 반드시 /setup-matt-pocock-skills 포함해서 설치
```
- 설치 후 초기화(호출): `/setup-matt-pocock-skills` (이슈트래커·라벨·문서 위치 설정)
- 개별 호출(슬래시):

| 스킬 | 용도 | 호출 |
|------|------|------|
| tdd | red-green-refactor 테스트 주도 | `/tdd` |
| to-prd | 대화 → PRD(명세) | `/to-prd` |
| implement | PRD/이슈 기반 구현 | `/implement` |
| code-review | 표준+스펙 2축 병렬 리뷰 | `/code-review` |
| diagnosing-bugs | 버그·성능 진단 루프 | `/diagnosing-bugs` |
| handoff | 세션 인계 문서화 | `/handoff` |
| research | 리서치 | `/research` |
| to-issues | 이슈 분해 | `/to-issues` |
| triage | 트리아지 | `/triage` |
| git-guardrails-claude-code | 위험 git 차단 훅 자동 설치 | `/git-guardrails-claude-code` |

---

## B. 서브에이전트 — ECC 선별 (mattpocock에 없는 보안·평가 보강)

- 용도: 시크릿·인증/인가·예외·타입·상태 검증 (Generator-Evaluator 분리)
- 저장소: https://github.com/affaan-m/ECC (MIT)
- 설치(선별 파일 복사 — 전체 설치 금지):
```bash
git clone --depth 1 https://github.com/affaan-m/ECC /tmp/ECC
mkdir -p ~/.claude/agents ~/.claude/skills
cp /tmp/ECC/agents/security-reviewer.md      ~/.claude/agents/
cp /tmp/ECC/agents/agent-evaluator.md        ~/.claude/agents/
cp /tmp/ECC/agents/silent-failure-hunter.md  ~/.claude/agents/
cp /tmp/ECC/agents/code-reviewer.md          ~/.claude/agents/
cp /tmp/ECC/agents/react-reviewer.md         ~/.claude/agents/
cp -R /tmp/ECC/skills/hookify-rules          ~/.claude/skills/
cp -R /tmp/ECC/skills/strategic-compact      ~/.claude/skills/
```
- 호출: 서브에이전트는 description 매칭으로 자동 위임되거나, 명시적으로 "use the security-reviewer agent" 로 호출

| 에이전트 | 용도 | 호출(명시) |
|----------|------|-----------|
| security-reviewer | 시크릿·인증/인가·인젝션 | "use security-reviewer" |
| agent-evaluator | SC·타입/계약 검증 | "use agent-evaluator" |
| silent-failure-hunter | 삼켜진 예외 탐지 | "use silent-failure-hunter" |
| code-reviewer | 가독성·구조 리뷰 | "use code-reviewer" |
| react-reviewer | React 상태관리 검증 | "use react-reviewer" |

---

## C. SDD 킷 — GSD (선택, 프로세스 자동화)

- 용도: 명세 주도 개발(스펙→로드맵→플랜→구현→검증), Context Rot 방지
- 저장소: https://github.com/gsd-build/get-shit-done (MIT)
- 설치:
```bash
npx get-shit-done-cc --local     # 현재 프로젝트에 설치 (--global 도 가능)
```
- 호출(슬래시):
```
/gsd:new-project → /gsd:create-roadmap → /gsd:plan-phase → /gsd:execute-plan → /gsd:verify
```
- ⚠️ mattpocock 스킬과 철학이 상반(통제권). 초급은 A로 시작, GSD는 중급 옵션으로 분리 권장.

---

## D. 토큰 관리 / 플러그인 (필요 시)

### D-1. LSP (코드 탐색 토큰 절감)
- 용도: 정의·참조를 좌표로 축소해 탐색 토큰 대폭 절감
- 저장소: https://github.com/Piebald-AI/claude-code-lsps
- 설치:
```bash
npx tweakcc --apply                                   # CC 빌트인 LSP 활성화 패치
npm install -g @vtsls/language-server typescript      # TS 언어서버 (Java는 JDT LS 별도)
```
- Claude Code 안에서:
```
/plugin marketplace add Piebald-AI/claude-code-lsps
/plugins    → i 로 필요한 언어 플러그인 설치
```
- 호출: 자동(코드 탐색 도구로 동작)

### D-2. codesight (세션 시작 구조맵)
- 용도: 코드베이스 구조를 압축 맵 1개로 → 세션 시작 토큰 절감
- 저장소: https://github.com/Houseofmvps/codesight
- 설치·호출:
```bash
npx codesight --init      # 구조맵 생성
npx codesight --mcp       # MCP로 연결(선택)
```

### D-3. superpowers (스킬 프레임워크, zero-dep)
- 용도: 조합 가능한 스킬 실행 프레임워크
- 저장소: https://github.com/obra/superpowers
- 설치(Claude Code 안에서):
```
/plugin install superpowers@claude-plugins-official
# 또는
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace
```
- 호출: 자동(스킬로 동작)

### D-4. caveman (출력 압축)
- 용도: 응답을 telegraphic하게 압축(토큰 절감)
- 저장소: https://github.com/JuliusBrussee/caveman
- 설치:
```bash
curl -fsSL https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.sh | bash   # mac/linux
# Windows(PowerShell): irm https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.ps1 | iex
```
- 호출: `/caveman` 또는 "talk like caveman" (Claude Code는 설치 시 자동 on / "normal mode"로 해제)

### D-5. headroom (API 페이로드 압축)
- 용도: grep·diff 등 API 페이로드를 프록시에서 압축
- 저장소: https://github.com/chopratejas/headroom
- 설치·호출:
```bash
pip install --user headroom
headroom wrap claude      # claude 실행을 headroom으로 감싸 실행
```

---

## E. 일괄 설치 블록 (초급 필수만 — 복사 실행용)

```bash
# 1) 스킬 세트 (대화형)
npx skills@latest add mattpocock/skills   # → /setup-matt-pocock-skills 포함 선택

# 2) 보안·평가 에이전트 (ECC 선별)
git clone --depth 1 https://github.com/affaan-m/ECC /tmp/ECC
mkdir -p ~/.claude/agents
cp /tmp/ECC/agents/security-reviewer.md ~/.claude/agents/
cp /tmp/ECC/agents/agent-evaluator.md ~/.claude/agents/
cp /tmp/ECC/agents/silent-failure-hunter.md ~/.claude/agents/

# 3) (선택) LSP 토큰 절감
npx tweakcc --apply
npm install -g @vtsls/language-server typescript
```
설치 후 Claude Code에서: `/setup-matt-pocock-skills` 실행 → `/plugin marketplace add Piebald-AI/claude-code-lsps`

---

## F. 검증 / 출처

| 항목 | 상태 | 근거 |
|------|:---:|------|
| mattpocock 설치 `npx skills@latest add` + 개별 슬래시 | ✅ | 레포 README |
| superpowers 설치(`/plugin install superpowers@...`) | ✅ | 레포 README |
| LSP 설치(`npx tweakcc --apply` + marketplace) + vtsls | ✅ | 레포 README |
| caveman 설치(install.sh / install.ps1) + `/caveman` | ✅ | 레포 README |
| headroom `pip install` + `headroom wrap claude` | ✅ | 레포 README |
| GSD `npx get-shit-done-cc` + `/gsd:*` | ✅ | 프로젝트 자료 + repo |
| codesight `npx codesight --init` | ✅ | 프로젝트 자료 + repo |
| 저장소 링크 7종 | ✅ | curl HTTP 200 |
| ECC 서브에이전트 호출 방식(자동 위임/명시) | ⚠️ 재확인 | CC 버전별 서브에이전트 트리거 방식 차이 — `/agents`로 확인 |
| 각 스킬/플러그인 버전·플래그 최신성 | ⚠️ | 도입 시 각 README·`/plugins`로 현행 확인 |

**출처**: 각 GitHub README(mattpocock/skills·ECC·superpowers·claude-code-lsps·caveman·headroom·get-shit-done), Claude Code 공식 문서(code.claude.com/docs/en/plugin-marketplaces), 프로젝트 내부 자료(클로드 코드 마스터).
