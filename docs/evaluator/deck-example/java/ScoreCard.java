import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 빌드 건강도 채점표 - 발표자료 66~68p 의 100점 만점 채점표를 그대로 구현한다.
 *
 * <p>이 클래스는 LLM 을 호출하지 않는다. 빌드·테스트·린트를 실제로 돌린 결과를 받아
 * 점수를 계산할 뿐이다. 결정론 층을 먼저 두껍게 깔라는 원칙이 코드 형태로 드러나는 자리다.
 *
 * <p>핵심 규칙 세 가지:
 * <ol>
 *   <li>G1(빌드)·G2(테스트)·G3(안전)은 거부권을 갖는다. 하나라도 0이면 총점과 무관하게 FAIL.
 *   <li>못 잰 항목은 skipped 로 표시하고 분모에서 뺀다. 조용한 통과를 만들지 않는다.
 *   <li>잴 수 있는 항목이 하나도 없으면 PASS 가 아니라 UNABLE 이다(fail-closed).
 * </ol>
 */
public final class ScoreCard {

    /** 배점 - 발표자료 66p 표와 동일하다. 합 100. */
    public static final Map<String, Integer> WEIGHTS = new LinkedHashMap<>();

    static {
        WEIGHTS.put("g1_build", 25);
        WEIGHTS.put("g2_test", 25);
        WEIGHTS.put("g3_safety", 15);
        WEIGHTS.put("lint", 10);
        WEIGHTS.put("regression", 10);
        WEIGHTS.put("coverage", 5);
        WEIGHTS.put("antislop", 10);
    }

    /** 거부권 항목. 이 셋 중 하나라도 0점이면 총점이 아무리 높아도 실패다. */
    public static final List<String> VETO_ITEMS = List.of("g1_build", "g2_test", "g3_safety");

    public static final double PASS_RATIO = 0.9;

    public enum Verdict { PASS, FAIL, UNABLE }

    /**
     * 한 항목의 측정 결과. value 가 null 이면 "재지 못했다"는 뜻이고 skipped 로 분류된다.
     * 측정 실패를 0점으로 바꾸지 않는 것이 중요하다 - 0점은 "쟀는데 나빴다"이고
     * skipped 는 "재지 못했다"이며 둘은 다른 판단을 부른다.
     */
    public record Measurement(Double value, String evidence) {
        public static Measurement of(double v) { return new Measurement(v, ""); }
        public static Measurement notMeasured(String why) { return new Measurement(null, why); }

        /** 명령의 종료 코드를 측정값으로. 못 돌렸으면 exitCode 에 null 을 준다. */
        public static Measurement fromExitCode(Integer exitCode, String command) {
            if (exitCode == null) return notMeasured(command + " - 실행 불가(툴체인 없음)");
            return new Measurement(exitCode == 0 ? 1.0 : 0.0, command + " -> exit " + exitCode);
        }

        /** 커버리지 비율을 측정값으로. 리포트가 없으면 pct 에 null 을 준다. */
        public static Measurement fromCoverage(Double pct, double minimum) {
            if (pct == null) return notMeasured("커버리지 리포트 없음");
            double ratio = pct >= minimum ? 1.0 : pct / minimum;
            return new Measurement(ratio, String.format("coverage %.0f%% (기준 %.0f%%)", pct * 100, minimum * 100));
        }
    }

    public record Result(
            String stack,
            Map<String, Integer> items,
            List<String> skipped,
            Map<String, String> evidence,
            int total,
            int max,
            Verdict verdict) {

        @Override
        public String toString() {
            return "ScoreCard{stack=" + stack + ", total=" + total + "/" + max
                    + ", verdict=" + verdict + ", items=" + items + ", skipped=" + skipped + "}";
        }
    }

    private ScoreCard() {}

    /** 측정 결과를 채점표로 바꾼다. WEIGHTS 에 있는데 빠진 키는 skipped 로 처리한다. */
    public static Result score(String stack, Map<String, Measurement> measurements) {
        Map<String, Integer> items = new LinkedHashMap<>();
        Map<String, String> evidence = new LinkedHashMap<>();
        List<String> skipped = new ArrayList<>();
        int max = 0;

        for (Map.Entry<String, Integer> e : WEIGHTS.entrySet()) {
            String key = e.getKey();
            int weight = e.getValue();
            Measurement m = measurements.get(key);
            if (m == null || m.value() == null) {
                skipped.add(key);            // 분모에서 뺀다. 0점으로 깎지 않는다.
                continue;
            }
            items.put(key, (int) Math.round(weight * clamp01(m.value())));
            max += weight;
            if (m.evidence() != null && !m.evidence().isEmpty()) evidence.put(key, m.evidence());
        }

        int total = items.values().stream().mapToInt(Integer::intValue).sum();

        // 잴 수 있는 항목이 없으면 통과시키지 않는다. 빈 채점표가 만점처럼 보이면 안 된다.
        if (max == 0) {
            return new Result(stack, items, skipped, evidence, 0, 0, Verdict.UNABLE);
        }

        List<String> vetoed = VETO_ITEMS.stream()
                .filter(k -> Integer.valueOf(0).equals(items.get(k)))
                .toList();

        Verdict verdict;
        if (!vetoed.isEmpty()) {
            verdict = Verdict.FAIL;
            evidence.put("veto", "거부권 발동: " + String.join(", ", vetoed));
        } else {
            verdict = ((double) total / max) >= PASS_RATIO ? Verdict.PASS : Verdict.FAIL;
        }

        return new Result(stack, items, skipped, evidence, total, max, verdict);
    }

    private static double clamp01(double v) {
        return v < 0 ? 0 : v > 1 ? 1 : v;
    }
}
