# 비교 하네스 셋업 (A~E)

라이브 비교를 위해 **동일 모델·동일 태스크·동일 프로젝트 스냅샷(git SHA)·동일 시드**를 고정하고
하네스만 교체한다(기준 §0). 각 환경을 별도 디렉토리/계정/컨테이너로 격리해 상호 오염을 막는다.

| ID | 하네스 | 셋업 |
|----|--------|------|
| A | No-Harness | 하네스 없이 단일 에이전트(베이스라인) |
| B | OpenHarness | `curl -fsSL .../install.sh \| bash` (HKUDS/OpenHarness) |
| C | ECC | `npx ecc-install <lang>` 또는 `/plugin install ecc@ecc` |
| D | Squad-only | `bash install.sh` (claude-code-expert/subagents) |
| E | carve | `npx carve-harness install <project>` (대상) |

> 주의: B·C·D는 외부 설치물(이 리포 vendor에는 없음). 라이선스·격리 환경을 확인하고 셋업한다.
> 측정은 각 하네스로 `bench/tasksets/*`를 n>=5 실행 → `bench/results/<id>.json` 기록 → `node bench/report.mjs`.
