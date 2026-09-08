import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 5축 루브릭 채점기 - checklist-loop 의 P3 Score 단계를 그대로 구현한다.
 *
 * <p>축과 배점(합 100):
 * <pre>
 *   exists     25   주장한 산출물이 실제로 존재하는가
 *   match      25   acceptance 를 문자 그대로 충족하는가
 *   test       25   테스트가 실행됐고 통과했는가   &lt;- 실행 출력으로만 채운다
 *   contract   15   스키마·시그니처 등 계약을 지켰는가
 *   no_regress 10   기존 동작을 깨뜨리지 않았는가
 * </pre>
 *
 * <p>test 축이 이 설계의 핵심이다. 실행 결과가 없으면 test=0 이 되고, 나머지를 만점 받아도
 * 합이 75라 임계 95를 넘지 못한다. 즉 "테스트를 돌리지 않은 채 완료를 주장하는 것"이
 * 산술적으로 불가능하다. 게이트에 별도 규칙을 넣지 않아도 배점 자체가 막는다.
 */
public final class RubricJudge {

    public static final Map<String, Integer> AXES = new LinkedHashMap<>();

    static {
        AXES.put("exists", 25);
        AXES.put("match", 25);
        AXES.put("test", 25);
        AXES.put("contract", 15);
        AXES.put("no_regress", 10);
    }

    public static final int DEFAULT_THRESHOLD = 95;
    public static final String DOMAIN_SAFETY = "domain_safety";

    /** 테스트 실행 결과. 실행하지 않았으면 ran=false 이고 test 축은 0점이 된다. */
    public record TestRun(boolean ran, int passed, int failed) {
        public static TestRun notRun() { return new TestRun(false, 0, 0); }

        public double ratio() {
            int total = passed + failed;
            if (!ran || total == 0) return 0.0;
            return (double) passed / total;
        }
    }

    public record Verdict(
            String taskId,
            Map<String, Integer> axes,
            int score,
            boolean passed,
            List<String> gaps,
            String evidence,
            String blockedBy) {

        @Override
        public String toString() {
            return "Verdict{" + taskId + " score=" + score + " pass=" + passed
                    + (blockedBy != null ? " blockedBy=" + blockedBy : "") + " axes=" + axes + "}";
        }
    }

    private RubricJudge() {}

    public static Verdict judge(String taskId, double exists, double match, double contract,
                                double noRegress, TestRun tests) {
        return judge(taskId, exists, match, contract, noRegress, tests, null, "", DEFAULT_THRESHOLD);
    }

    /** 다섯 축의 달성률(0.0~1.0)을 받아 채점한다. test 축만 실행 결과에서 계산한다. */
    public static Verdict judge(String taskId, double exists, double match, double contract,
                                double noRegress, TestRun tests, String taskType,
                                String evidence, int threshold) {
        Map<String, Double> raw = new LinkedHashMap<>();
        raw.put("exists", exists);
        raw.put("match", match);
        raw.put("test", tests.ratio());     // 실행하지 않았으면 0
        raw.put("contract", contract);
        raw.put("no_regress", noRegress);

        Map<String, Integer> axes = new LinkedHashMap<>();
        int total = 0;
        for (Map.Entry<String, Double> e : raw.entrySet()) {
            int earned = (int) Math.round(AXES.get(e.getKey()) * clamp01(e.getValue()));
            axes.put(e.getKey(), earned);
            total += earned;
        }

        List<String> gaps = new ArrayList<>();
        if (!tests.ran()) {
            gaps.add("테스트 미실행 - test 축 0점, 합 75 상한이라 임계를 넘을 수 없다");
        }

        boolean passed = total >= threshold;
        String blockedBy = null;
        // 도메인 안전 항목은 만점 아니면 차단. 임계보다 엄격하다.
        if (DOMAIN_SAFETY.equals(taskType) && total < 100) {
            passed = false;
            blockedBy = DOMAIN_SAFETY + ": 100점이 아니면 차단(허용 실패율 0%)";
        }

        return new Verdict(taskId, axes, total, passed, gaps, evidence, blockedBy);
    }

    /**
     * 루프를 계속할지 판정한다. 미달 항목만 재작업 대상으로 돌려준다.
     * 통과한 항목은 건드리지 않는다 - 전체 재생성이 아니라 미달만 고치는 것이
     * 빠르고, 이미 좋은 것을 망치지 않는다(발표자료 75p).
     */
    public record LoopStatus(int threshold, int totalTasks, int passing, List<String> rework, String gate) {}

    public static LoopStatus loopStatus(List<Verdict> verdicts, int threshold) {
        List<String> rework = verdicts.stream().filter(v -> !v.passed()).map(Verdict::taskId).toList();
        return new LoopStatus(threshold, verdicts.size(), verdicts.size() - rework.size(),
                rework, rework.isEmpty() ? "RELEASED" : "BLOCKED");
    }

    private static double clamp01(double v) {
        return v < 0 ? 0 : v > 1 ? 1 : v;
    }
}
