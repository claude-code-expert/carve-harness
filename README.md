# Claude 하네스 템플릿 (언어 무관 드롭인)

Java/Spring · React/Next 공통으로 쓰는 하네스 뼈대. 프로젝트 루트에 그대로 복사해 사용한다.

## 설치 (드롭인)
```bash
# 1) 이 템플릿 내용을 프로젝트 루트에 복사
cp -R claude-harness-template/. /path/to/your-project/
# 2) 훅 실행 권한
chmod +x /path/to/your-project/.claude/hooks/*.sh
# 3) 전제 도구: jq(훅), pnpm(프론트), gradlew(백엔드)
```

## GSD로 하네스 구성 (SDD)
```bash
# 프로젝트 루트에서 GSD 설치 (온라인)
npx get-shit-done-cc --local
# 워크플로우
/gsd:new-project → /gsd:create-roadmap → /gsd:plan-phase → /gsd:execute-plan → /gsd:verify
# 산출물은 specs/ 에 축적 (핸드오프/결정기록과 함께 상태 기둥 형성)
```

## 구조
```
├── CLAUDE.md            # 제약: 전역 가드레일
├── AGENTS.md            # 에이전트 표준
├── RULES.md             # 룰 인덱스
├── specs/               # 상태: SDD 산출물 + HANDOFF/DECISIONS
└── .claude/
    ├── settings.json    # 훅 등록 (Pre/Post/Stop/Session/PreCompact)
    ├── hooks/           # 언어 자동감지 훅 4종
    ├── skills/          # handoff, changelog
    ├── commands/        # plan, verify, review, commit, harness-audit
    ├── agents/          # evaluator, code/security/silent-failure/state reviewer
    └── rules/           # common + java-spring + react-next (paths glob)
```

## 3기둥 매핑
- 제약: CLAUDE.md + rules/ + pretool-guard.sh
- 피드백: posttool-format.sh + stop-verify.sh + agents/
- 상태: session-handoff.sh + specs/

> ⚠️ 훅 문법·이벤트는 Claude Code 버전에 따라 바뀔 수 있으니 도입 시 `/hooks`로 확인.
