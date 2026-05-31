---
name: security-scan
description: >
  보안 스캔 게이트 — 변경·생성물의 시크릿 노출·인젝션·과도 권한을 점검한다.
  "보안 스캔", "취약점 점검", "security scan" 요청에 사용. 깊은 감사는 squad-audit에 위임.
---
# security-scan — 보안 게이트

- 변경 파일에서 secret(키·토큰·`.env`)·인젝션·과도 권한·하드코딩 비밀번호를 점검한다.
- 깊은 감사는 `squad-audit` 서브에이전트에 위임한다(`/squad audit`).
- 배포 전 0건을 확인한다. 발견 시 차단하고 수정 후 재스캔한다.
