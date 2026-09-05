# `.claude/rules/java-spring/` — Java/Spring 규칙 (java 팩)

`**/*.java`를 열면 자동 로드. `java-spring` 언어팩과 함께 설치된다.

| 파일 | glob | 내용 |
|---|---|---|
| `patterns.md` | `**/*.java` | 계층 분리·생성자 주입·트랜잭션·DTO 매핑 |
| `gateway-testing.md` | `**/*Gateway*.java` 등 | 게이트웨이 5기능 통합 테스트 SC (GATE-04가 강제) |
| `archunit/` | — | 규칙-as-테스트 템플릿 (아래 README) |

## 사용방법
- 자동 로드. 상세본은 `docs/rules/code-convention/dev-stack-java-spring.md`.
- 게이트웨이 파일 변경 시 `stop-verify`가 `*GatewayIntegration*` 통합 테스트만 증분 실행.

> 감사 AUDIT-07이 "게이트웨이 규칙 ↔ Stop 게이트 트리거" 매핑을, AUDIT-08이 "eval-java ↔ archunit 동반"을 검사.
