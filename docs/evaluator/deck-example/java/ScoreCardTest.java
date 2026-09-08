import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 채점기를 채점하는 테스트.
 *
 * <p>발표자료 87p - 점수가 이상할 때 의심 순서는 ① 채점기 ② 문항 ③ 에이전트다.
 * 에이전트를 맨 마지막에 의심하는 이유는 점수 하락의 상당수가 채점기 버그이기 때문이다.
 * 그러니 채점기에도 테스트가 있어야 한다. 이 파일이 그 테스트다.
 *
 * <p>빌드 도구·JUnit 없이 실행:
 * <pre>
 *   java ScoreCardTest.java          (JDK 11+ 단일 파일 실행)
 *   javac *.java &amp;&amp; java ScoreCardTest
 * </pre>
 * 실패가 하나라도 있으면 exit 1 로 끝나므로 CI 게이트에 그대로 걸 수 있다.
 */
public class ScoreCardTest {

    static final List<String> FAILS = new ArrayList<>();

    static void check(boolean cond, String label, Object detail) {
        if (cond) {
            System.out.println("  PASS  " + label);
        } else {
            FAILS.add(label);
            System.out.println("  FAIL  " + label);
            if (detail != null) System.out.println("        " + detail);
        }
    }

    static void check(boolean cond, String label) { check(cond, label, null); }

    static void section(String title) { System.out.println("\n[" + title + "]"); }

    static Map<String, ScoreCard.Measurement> allGreen() {
        Map<String, ScoreCard.Measurement> m = new LinkedHashMap<>();
        for (String k : ScoreCard.WEIGHTS.keySet()) m.put(k, ScoreCard.Measurement.of(1.0));
        return m;
    }

    public static void main(String[] args) {
        // ═══════════════════════════════════════════════════════════════
        section("채점표 - 거부권");

        ScoreCard.Result card = ScoreCard.score("java", allGreen());
        check(card.total() == 100 && card.verdict() == ScoreCard.Verdict.PASS,
                "전 항목 만점이면 100점 PASS", card);

        // 총점이 합격선을 넘어도 거부권 항목이 0이면 실패여야 한다. 채점표의 핵심.
        Map<String, ScoreCard.Measurement> vetoed = allGreen();
        vetoed.put("g3_safety", ScoreCard.Measurement.of(0.0));
        card = ScoreCard.score("java", vetoed);
        check(card.total() == 85 && card.verdict() == ScoreCard.Verdict.FAIL,
                "G3 안전 0점이면 총점 85여도 FAIL (거부권)", card);

        Map<String, ScoreCard.Measurement> lintZero = allGreen();
        lintZero.put("lint", ScoreCard.Measurement.of(0.0));
        card = ScoreCard.score("java", lintZero);
        check(card.total() == 90 && card.verdict() == ScoreCard.Verdict.PASS,
                "lint 0점은 거부권 아님 - 90/100 이면 PASS", card);

        section("채점표 - 못 잰 항목은 분모에서 뺀다");

        Map<String, ScoreCard.Measurement> noCov = allGreen();
        noCov.remove("coverage");
        card = ScoreCard.score("java", noCov);
        check(card.max() == 95 && card.skipped().contains("coverage"),
                "커버리지 미측정 시 분모 95로 축소되고 skipped 로 표시", card);
        check(card.verdict() == ScoreCard.Verdict.PASS, "축소된 분모 기준으로 합격 판정", card);

        card = ScoreCard.score("java", new LinkedHashMap<>());
        check(card.verdict() == ScoreCard.Verdict.UNABLE && card.total() == 0,
                "잴 수 있는 항목이 없으면 UNABLE (fail-closed)", card);

        section("채점표 - 측정 어댑터");

        check(ScoreCard.Measurement.fromExitCode(0, "gradle test").value() == 1.0, "exit 0 이면 만점");
        check(ScoreCard.Measurement.fromExitCode(1, "gradle test").value() == 0.0, "exit 1 이면 0점");
        check(ScoreCard.Measurement.fromExitCode(null, "gradle test").value() == null,
                "툴체인 없어 실행 못 하면 null - 0점이 아니라 skipped 로 간다");
        check(ScoreCard.Measurement.fromCoverage(null, 0.8).value() == null, "커버리지 리포트 없으면 skipped");
        check(ScoreCard.Measurement.fromCoverage(0.85, 0.8).value() == 1.0, "커버리지 85% >= 기준 80% 이면 만점");

        // ═══════════════════════════════════════════════════════════════
        section("루브릭 - test 축은 실행 출력으로만 채운다");

        RubricJudge.Verdict neverRan = RubricJudge.judge("x", 1, 1, 1, 1, RubricJudge.TestRun.notRun());
        check(neverRan.score() == 75 && !neverRan.passed(),
                "테스트 미실행이면 나머지 만점이어도 75점 - 거짓 완료 차단", neverRan);
        check(neverRan.gaps().stream().anyMatch(g -> g.contains("미실행")), "미실행 사유가 gap 에 남는다");

        RubricJudge.Verdict green = RubricJudge.judge("x", 1, 1, 1, 1, new RubricJudge.TestRun(true, 4, 0));
        check(green.score() == 100 && green.passed(), "전 축 충족이면 100점 통과");

        RubricJudge.Verdict partial = RubricJudge.judge("x", 1, 1, 1, 1, new RubricJudge.TestRun(true, 3, 1));
        check(partial.score() == 94 && !partial.passed(),
                "테스트 3/4 통과면 94점 - 94도 미달은 미달이다", partial);

        section("루브릭 - 도메인 안전 항목은 만점 아니면 차단");

        RubricJudge.Verdict near = RubricJudge.judge("safety", 1, 1, 1, 1,
                new RubricJudge.TestRun(true, 9, 1), RubricJudge.DOMAIN_SAFETY, "", RubricJudge.DEFAULT_THRESHOLD);
        check(!near.passed() && near.blockedBy() != null,
                "domain_safety 는 97점이어도 차단 (허용 실패율 0%)", near);

        // ═══════════════════════════════════════════════════════════════
        section("워크스루 재현 - 발표자료 74~75p 쿠폰 API");

        List<RubricJudge.Verdict> round1 = List.of(
                task("coupon-applies",        1.00, 1.00, 1.00, 1.00, 7, 1),   // 97
                task("coupon-no-reuse",       1.00, 0.80, 1.00, 1.00, 0, 3),   // 70
                task("coupon-expiry",         1.00, 0.68, 1.00, 1.00, 8, 0),   // 92
                task("coupon-response-shape", 1.00, 1.00, 1.00, 1.00, 5, 0));  // 100
        System.out.println("        1회차: " + scores(round1));
        check(scores(round1).equals(Map.of(
                        "coupon-applies", 97, "coupon-no-reuse", 70,
                        "coupon-expiry", 92, "coupon-response-shape", 100)),
                "1회차 점수가 발표자료 74p 표와 일치 (97/70/92/100)", scores(round1));

        RubricJudge.LoopStatus s1 = RubricJudge.loopStatus(round1, RubricJudge.DEFAULT_THRESHOLD);
        check("BLOCKED".equals(s1.gate()), "1회차 - 미달 항목이 있어 게이트 차단", s1);
        check(s1.rework().size() == 2 && s1.rework().contains("coupon-no-reuse")
                        && s1.rework().contains("coupon-expiry"),
                "미달 2개만 재작업 대상 - 통과한 항목은 건드리지 않는다", s1);

        List<RubricJudge.Verdict> round2 = List.of(
                round1.get(0),                                                 // 97 유지
                task("coupon-no-reuse",       1.00, 0.84, 1.00, 1.00, 6, 0),   // 96
                task("coupon-expiry",         1.00, 0.88, 1.00, 1.00, 8, 0),   // 97
                round1.get(3));                                                // 100 유지
        System.out.println("        2회차: " + scores(round2));
        check(scores(round2).equals(Map.of(
                        "coupon-applies", 97, "coupon-no-reuse", 96,
                        "coupon-expiry", 97, "coupon-response-shape", 100)),
                "2회차 점수가 발표자료 75p 표와 일치 (97/96/97/100)", scores(round2));

        RubricJudge.LoopStatus s2 = RubricJudge.loopStatus(round2, RubricJudge.DEFAULT_THRESHOLD);
        check("RELEASED".equals(s2.gate()) && s2.rework().isEmpty(),
                "2회차 - 전 항목 합격, 게이트 해제", s2);

        // ═══════════════════════════════════════════════════════════════
        section("채점기 버그 재현 - 87p '채점기부터 의심'");

        // 실화: 에이전트가 96.12 라고 정답을 냈는데 채점기가 표기 방식 차이로 0점을 줬다.
        // 채점기를 고치자 통과율이 42% -> 95% 로 뛰었다. 에이전트는 처음부터 죄가 없었다.
        String[][] answers = {{"96.12", "96.120"}, {"96.12", " 96.12"}, {"96.12", "96.12"}, {"100", "100.0"}};
        int naiveOk = 0, fixedOk = 0;
        for (String[] a : answers) {
            if (a[0].equals(a[1])) naiveOk++;
            if (numericMatch(a[0], a[1])) fixedOk++;
        }
        System.out.println("        같은 답, 나쁜 채점기 " + naiveOk + "/4  ->  고친 채점기 " + fixedOk + "/4");
        check(naiveOk == 1 && fixedOk == 4,
                "답은 그대로인데 채점기만 고쳐도 통과율이 뛴다 - 에이전트를 먼저 의심하면 안 되는 이유");

        section("극단 점수는 그 자체가 경보 - 87p");

        check(alarm(List.of(0, 0, 0)).startsWith("채점 환경"), "전원 0% 는 채점 환경 경보");
        check(alarm(List.of(100, 100)).startsWith("문항이"), "전원 100% 는 난이도 경보");
        check(alarm(List.of(97, 70, 92)).equals("정상 범위"), "섞인 점수는 정상");

        // ═══════════════════════════════════════════════════════════════
        System.out.println("\n" + "=".repeat(62));
        if (!FAILS.isEmpty()) {
            System.out.println("FAILED " + FAILS.size() + "건");
            FAILS.forEach(f -> System.out.println("  - " + f));
            System.exit(1);
        }
        System.out.println("전 항목 통과");
    }

    static RubricJudge.Verdict task(String id, double exists, double match, double contract,
                                    double noRegress, int passed, int failed) {
        return RubricJudge.judge(id, exists, match, contract, noRegress,
                new RubricJudge.TestRun(true, passed, failed));
    }

    static Map<String, Integer> scores(List<RubricJudge.Verdict> vs) {
        Map<String, Integer> m = new LinkedHashMap<>();
        vs.forEach(v -> m.put(v.taskId(), v.score()));
        return m;
    }

    /** 고친 채점기 - 숫자로 비교한다. */
    static boolean numericMatch(String expected, String actual) {
        try {
            return Math.abs(Double.parseDouble(expected.trim()) - Double.parseDouble(actual.trim())) <= 1e-9;
        } catch (NumberFormatException e) {
            return expected.trim().equals(actual.trim());
        }
    }

    static String alarm(List<Integer> scores) {
        if (!scores.isEmpty() && scores.stream().allMatch(s -> s == 0))
            return "채점 환경이 깨졌을 가능성 - 문항이 아니라 실행부터 확인";
        if (!scores.isEmpty() && scores.stream().allMatch(s -> s == 100))
            return "문항이 너무 쉬워졌을 가능성 - 난이도 갱신 필요";
        return "정상 범위";
    }
}
