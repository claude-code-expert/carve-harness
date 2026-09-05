# `.claude/hooks/` — 게이트·가드·헬퍼

`settings.json`이 이벤트에 배선하는 스크립트와, 그것들이 `source`로 공유하는 라이브러리·CLI 도구가 있다. **차단은 exit 2**, fail-closed가 원칙.

## 이벤트 게이트 (settings.json이 자동 호출)
| 파일 | 이벤트 | 역할 |
|---|---|---|
| `pretool-guard.sh` | PreToolUse | 보호 경로·시크릿·위험 명령 차단(exit 2), 루프 브레이크, 자기보호 |
| `posttool-format.sh` | PostToolUse | 스택 감지 후 포맷(비차단) |
| `stop-verify.sh` | Stop | 변경 스택 빌드·타입·테스트 게이트 |
| `checklist-gate.sh` | Stop | 검증 루프 미달 시 완료 차단 · `domain_safety` 거부권 |
| `session-handoff.sh` | SessionStart/PreCompact/SessionEnd | 핸드오프 저장·복원 + 구성 배너 |

## 라이브러리 (source 전용, 직접 실행 안 함)
`lib-protected.sh`(보호 경로·시크릿·위험 명령 정규식) · `lib-stop-guard.sh`(Stop 루프 가드) · `lib-packs.sh`(언어팩 매니페스트 리더).

## CLI·헬퍼 (수동/워크플로 호출)
`log-event.sh`(JSONL 관측) · `logs-report.sh` · `config-doctor.sh` · `harness-audit.sh`(구성 감사 AUDIT-01~09) · `eval-java.sh`(Java 스코어러) · `eval-score.sh`(언어 무관 채점표) · `eval-state.sh`·`eval-run.sh`·`eval-trend.sh`·`carve-validate.sh`·`eval-gate.sh`(골든셋 평가 파이프라인) · `redteam.sh`(가드레일 자기평가).

> `tests/`에 훅별 어서션 스위트. 새 훅·스택은 `bash -n`과 스위트가 감사에 걸린다.
