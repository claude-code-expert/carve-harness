// Harness eval — build wiring for the deterministic Java/Spring evaluator.
// Adds the reports that .claude/hooks/eval-java.sh parses into a reproducible P.
//
// Usage: apply from the project's build.gradle.kts:
//   apply(from = "harness/build-eval.gradle.kts")
// or copy the blocks below in. Requires the java + jvm-test-suite ecosystem.
//
// Produces (all XML — eval-java.sh reads these, never HTML):
//   build/reports/jacoco/test/jacocoTestReport.xml   ← coverage %
//   build/reports/pmd/main.xml                        ← PMD violations
//   build/reports/checkstyle/main.xml                 ← Checkstyle violations
//   build/reports/spotbugs/main.xml                   ← SpotBugs violations
//   build/test-results/test/*.xml                     ← test pass/fail (pass^k)
//   ArchUnit rules run as ordinary tests (HarnessArchRulesTest) → in test-results.

plugins {
    jacoco
    pmd
    checkstyle
    id("com.github.spotbugs") version "6.0.26"   // 버전은 프로젝트 gradle/plugin 호환성에서 재확인
}

dependencies {
    // ArchUnit — rules-as-tests. HarnessArchRulesTest가 이 의존성을 쓴다.
    testImplementation("com.tngtech.archunit:archunit-junit5:1.3.0")
}

// ── 커버리지: XML 리포트 강제 (eval-java.sh 파싱 대상) ──
jacoco {
    toolVersion = "0.8.12"
}
tasks.jacocoTestReport {
    dependsOn(tasks.test)
    reports {
        xml.required.set(true)      // eval-java.sh가 읽는 형식
        html.required.set(false)    // 불필요 산출물 억제
    }
}

// ── 정적분석: 리포트를 XML로, 위반이 있어도 빌드는 계속(스코어러가 밀도로 환산) ──
pmd {
    isConsoleOutput = false
    isIgnoreFailures = true         // 위반=빌드실패 아님 → eval이 밀도로 점수화
    toolVersion = "7.7.0"
}
tasks.withType<Pmd>().configureEach {
    reports {
        xml.required.set(true)
        html.required.set(false)
    }
}

checkstyle {
    isIgnoreFailures = true
    // config는 프로젝트 config/checkstyle/checkstyle.xml (Google 규칙 권장 — patterns.md §3)
    toolVersion = "10.20.1"
}
tasks.withType<Checkstyle>().configureEach {
    reports {
        xml.required.set(true)
        html.required.set(false)
    }
}

spotbugs {
    ignoreFailures.set(true)
}
tasks.withType<com.github.spotbugs.snom.SpotBugsTask>().configureEach {
    reports.create("xml") { required.set(true) }
}

// ── 테스트: JUnit5 + JaCoCo 커버리지 수집. pass^k는 eval-java.sh가 test를 k회 돌려 계산 ──
tasks.test {
    useJUnitPlatform()
    finalizedBy(tasks.jacocoTestReport)
    testLogging { events("failed") }
}

// (선택) 커버리지 하한을 빌드에서 강제하려면 — 하네스 스코어러와 별개로도 게이트 가능:
// tasks.jacocoTestCoverageVerification {
//     violationRules { rule { limit { minimum = "0.80".toBigDecimal() } } }
// }
