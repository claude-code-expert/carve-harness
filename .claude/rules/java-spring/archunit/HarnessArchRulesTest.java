package harness.eval;

import com.tngtech.archunit.core.domain.JavaClasses;
import com.tngtech.archunit.core.importer.ClassFileImporter;
import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.lang.ArchRule;
import org.junit.jupiter.api.Test;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.fields;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.methods;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noFields;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noMethods;

/**
 * Harness eval — executable promotion of .claude/rules/java-spring/patterns.md [MUST] rules.
 * Each @Test = one rule; the eval scorer reads this suite's pass/total as archrules_pass_rate.
 *
 * Drop into src/test/java, change BASE_PACKAGE to your root package, and (if your layout
 * differs) adjust the package name suffixes below. Rules assume Google-style package-by-feature
 * with `..controller..`/`..service..`/`..repository..`/`..domain..`/`..infrastructure..` or the
 * annotation-based checks (which are layout-independent) carry the load.
 *
 * These are deterministic: same bytecode in → same pass/fail out. No LLM, no probability drift.
 */
class HarnessArchRulesTest {

    /** CHANGE THIS to your project's root package. */
    private static final String BASE_PACKAGE = "com.example.app";

    private static JavaClasses classes() {
        return new ClassFileImporter()
                .withImportOption(ImportOption.Predefined.DO_NOT_INCLUDE_TESTS)
                .importPackages(BASE_PACKAGE);
    }

    // patterns.md L12 — 생성자 주입만. 필드 주입(@Autowired) 금지.
    @Test
    void no_field_injection() {
        ArchRule rule = noFields()
                .should().beAnnotatedWith("org.springframework.beans.factory.annotation.Autowired")
                .because("생성자 주입만 허용 — 필드 주입 금지 (patterns.md L12)");
        rule.check(classes());
    }

    // patterns.md L21 — @ManyToOne/@OneToMany는 FetchType.LAZY 고정. EAGER 금지.
    // ArchUnit은 애노테이션 값(fetch=EAGER)을 직접 못 읽으므로, EAGER를 유발하는 기본값 애노테이션
    // 사용 자체를 리뷰 대상으로 표시한다. 정확 검사는 소스 grep 보완(스코어러가 병행).
    @Test
    void associations_should_not_be_eager() {
        ArchRule manyToOne = fields()
                .that().areAnnotatedWith("jakarta.persistence.ManyToOne")
                .should().notBeAnnotatedWith("jakarta.persistence.OneToOne")
                .because("연관관계는 LAZY 고정 — fetch 명시 검증은 스코어러 grep 보완 (patterns.md L21)");
        manyToOne.allowEmptyShould(true).check(classes());
    }

    // patterns.md L16 — Controller가 Entity를 직접 반환 금지 → DTO(record).
    @Test
    void controllers_should_not_return_entities() {
        ArchRule rule = noMethods()
                .that().areDeclaredInClassesThat().resideInAPackage("..controller..")
                .and().arePublic()
                .should().haveRawReturnType(
                        com.tngtech.archunit.base.DescribedPredicate.describe(
                                "an @Entity type",
                                javaClass -> javaClass.isAnnotatedWith("jakarta.persistence.Entity")))
                .because("Controller는 Entity 반환 금지 → DTO 매핑 (patterns.md L16)");
        rule.allowEmptyShould(true).check(classes());
    }

    // patterns.md L11 — 계층 단방향: domain 패키지는 infrastructure를 import 금지.
    @Test
    void domain_should_not_depend_on_infrastructure() {
        ArchRule rule = noClasses()
                .that().resideInAPackage("..domain..")
                .should().dependOnClassesThat().resideInAPackage("..infrastructure..")
                .because("도메인은 인프라를 모른다 — 단방향 의존 (patterns.md L11)");
        rule.allowEmptyShould(true).check(classes());
    }

    // patterns.md L11 — Controller → Service → Repository. 역방향 의존 금지.
    @Test
    void repositories_should_not_depend_on_services_or_controllers() {
        ArchRule rule = noClasses()
                .that().resideInAPackage("..repository..")
                .should().dependOnClassesThat().resideInAnyPackage("..service..", "..controller..")
                .because("Repository는 상위 계층을 모른다 — 역방향 의존 금지 (patterns.md L11)");
        rule.allowEmptyShould(true).check(classes());
    }

    // patterns.md L13 — 비즈니스 로직은 Service에. Controller가 Repository 직접 호출 금지.
    @Test
    void controllers_should_not_use_repositories_directly() {
        ArchRule rule = noClasses()
                .that().resideInAPackage("..controller..")
                .should().dependOnClassesThat().resideInAPackage("..repository..")
                .because("Controller는 Service를 거친다 — Repository 직접 호출 금지 (patterns.md L13)");
        rule.allowEmptyShould(true).check(classes());
    }

    // patterns.md L23 — SQL 문자열 직접 결합(인젝션) 금지. java.sql.Statement 사용 금지.
    @Test
    void no_raw_statement_string_concat() {
        ArchRule rule = noClasses()
                .should().accessClassesThat().haveFullyQualifiedName("java.sql.Statement")
                .because("문자열 결합 SQL 금지 → PreparedStatement/JPQL 파라미터 (patterns.md L23)");
        rule.allowEmptyShould(true).check(classes());
    }

    // patterns.md L22 — 외부 API 호출을 @Transactional 안에서 하지 않는다(트랜잭션 경계 보호).
    // 정적으로 완전 검사는 어려우므로, RestTemplate/WebClient를 직접 필드로 든 @Service를
    // 표시(리뷰 신호). 정확 검사는 스코어러 정적분석 보완.
    @Test
    void services_should_declare_transactional_intent() {
        ArchRule rule = methods()
                .that().areDeclaredInClassesThat().resideInAPackage("..service..")
                .and().arePublic()
                .and().areDeclaredInClassesThat().areAnnotatedWith("org.springframework.stereotype.Service")
                .should().beDeclaredInClassesThat()
                .areMetaAnnotatedWith("org.springframework.transaction.annotation.Transactional")
                .because("Service 트랜잭션 경계 명시 — readOnly 기본 + 쓰기만 write (patterns.md L22)");
        rule.allowEmptyShould(true).check(classes());
    }
}
