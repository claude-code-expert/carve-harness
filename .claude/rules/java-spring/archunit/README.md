# `.claude/rules/java-spring/archunit/` — ArchUnit 템플릿

`patterns.md`의 계층 규칙(Controller→Service→Repository 단방향 등)을 **실행 가능한 테스트로** 승격하는 템플릿. 규칙을 문장이 아니라 검사로 강제한다.

| 파일 | 무엇 |
|---|---|
| `HarnessArchRulesTest.java` | ArchUnit 규칙-as-테스트 (JUnit). 계층·의존 방향·네이밍 검증 |
| `build-eval.gradle.kts` | `eval-java.sh`가 파싱할 리포트(JaCoCo·PMD·Checkstyle·SpotBugs·test-results XML) 배선 |

## 사용방법
- 프로젝트 `build.gradle.kts`에서 `apply(from = "…/build-eval.gradle.kts")` 후 `HarnessArchRulesTest.java`를 test 소스에 복사.
- `./gradlew test`가 ArchUnit 규칙을 검증하고, `eval-java.sh`가 리포트를 결정적 품질 확률 P로 파싱.

> `eval-java.sh`와 이 폴더는 하드 의존(AUDIT-08) — 함께 설치·제거된다. Java 미감지면 둘 다 없다.
