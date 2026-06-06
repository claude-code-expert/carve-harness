# HARNESS-GUIDE — carve로 설치된 하네스

## 무엇이 설치됐나
{{COMPONENT_LIST}}

## 사용법
- **스킬**: 자연어로 트리거 — "커밋 메시지 만들어", "리뷰해줘", "핸드오프 정리".
- **서브에이전트**: `/squad review`, `/squad qa`, `/squad audit` 등 단일 책임 위임.
- **훅**: 자동 동작(차단·포맷·알림). `.claude/settings.json`에 등록됨.
- **하네스 재구성**: "이 프로젝트에 맞는 하네스 구성해줘" → harness-architect 스킬이 안내.

{{ITERATE_SECTION}}## 계획 우선 / 단계 확인
새 기능·비자명 변경은 계획(Spec)을 먼저 제시하고 **승인 후** 구현하며, 각 단계마다 확인을 받는다
(`squad-plan` + `sprint-contract.md`의 Plan Gate, `squad-evaluator`가 계획·산출물을 정량 채점).

## 정직 표기 / 범위 밖 (out-of-fit)
- **OS 샌드박스/컨테이너 없음** — 루프는 프로젝트 트리(선택적으로 git worktree)에서 실행. 진짜 프로세스 격리는 호스트 책임.
- **계획 승인·단계 확인은 모델 지시 워크플로**, 훅 강제가 아니다. carve는 안전 경계(파괴/비밀)만 결정적 강제(exit 2).
- **라이브 컨텍스트 점유율 측정 불가** — PreCompact 빈도만 proxy로 기록(`carve report`).
- **루프 텔레메트리는 pass/fail만** 기록, 반복 깊이는 기록하지 않는다(스키마 `{ts,hook,event}` 유지).

## anti-slop 보장
HTML·SVG·카드뉴스·리포트·슬라이드·문서 생성 시 AI 슬롭(그라데이션·글로우/컬러 그림자·모션 장식·
워터마크·마케팅 보일러플레이트)을 제거하고, 위계는 크기·여백·정렬·타이포로 만든다.
생성 후 `check-slop.mjs`가 결정적으로 검사한다(경고 모드 — 의도적 사용은 예외경로).

## 안전
- 위험 명령·비밀 파일은 결정적으로 차단된다(exit 2). 우회 금지.
- 생성물은 설치 전 auditor가 secret·과도 권한·훅 주입을 스캔한다.

## 제거
```bash
npx carve-harness uninstall   # 설치 자산 클린 제거 + .bak 복원
```
