---
name: handoff
description: 세션 종료·컨텍스트 압축 직전에 진행 상황을 specs/HANDOFF.md로 인계한다. 긴 작업의 연속성이 필요할 때 사용.
---
# handoff (세션 인계)
현재 브랜치·미완료 TODO·핵심 결정·다음 단계를 `specs/HANDOFF.md`에 구조화해 저장한다.
PreCompact/SessionStart 훅과 함께 동작한다.
## 출력 형식
- 진행 상황 / 미완료 / 다음 단계 / 주의점
> 프로젝트별 인계 항목은 이 아래에 추가한다 (예: 배포 상태, 미해결 티켓 번호, 롤백 절차).
