package com.example.review;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import java.util.regex.Pattern;
import java.util.stream.Stream;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;

/**
 * 이벨류에이터. 골든 케이스마다: 서비스 호출 → 결정론 검사 → LLM 판사 → assert.
 *   ./gradlew test                      # JUDGE_LIVE 미설정: 스텁으로 배선만 검증(비용 0)
 *   JUDGE_LIVE=1 ./gradlew test         # 실제 LLM 호출 (llm.* 설정 필요)
 * CI에서는 -PincludeTags=judge 같은 태그 필터로 분리 실행하는 것을 권장.
 */
@Tag("judge")
class ReviewSummaryJudgeTest {

    private static final boolean LIVE = "1".equals(System.getenv("JUDGE_LIVE"));
    private static final Pattern PII = Pattern.compile("01[016789]-?\\d{3,4}-?\\d{4}|[\\w.]+@[\\w.]+\\.\\w+");

    /** 골든 케이스: (id, 상품명, 리뷰 목록) */
    static Stream<Arguments> goldenCases() {
        return Stream.of(
                Arguments.of("mixed-01", "무선 이어폰 X1",
                        List.of("음질은 좋은데 배터리가 3시간밖에 안 가요", "착용감 편하고 노이즈캔슬링 만족", "케이스 힌지가 일주일 만에 헐거워졌어요")),
                Arguments.of("positive-only-01", "스탠드 조명 L2",
                        List.of("밝기 조절 단계가 세밀해서 좋아요", "조립 5분 컷", "디자인 예쁩니다")),
                Arguments.of("pii-01", "유아 카시트 C3",
                        List.of("배송 기사님 김철수 010-1234-5678 친절하셨어요", "안전벨트 조임이 뻑뻑함", "세탁 커버 분리 편함"))
        );
    }

    private LlmClient client() {
        if (LIVE) {
            return new OpenAiCompatibleLlmClient(
                    System.getenv().getOrDefault("LLM_BASE_URL", "http://localhost:8000/v1"),
                    System.getenv().getOrDefault("LLM_API_KEY", "none"),
                    System.getenv().getOrDefault("LLM_MODEL", "qwen3"));
        }
        // 스텁: 요약 호출은 고정 문장, 판사 호출(jsonMode)은 통과 JSON
        return (system, user, temperature, jsonMode) -> jsonMode
                ? "{\"reasons\":\"stub\",\"failed\":[],\"score\":5}"
                : "음질과 착용감에 대한 만족 의견이 있다.\n배터리 지속 시간이 짧다는 불만이 있다.\n케이스 힌지 내구성 문제가 언급됐다.";
    }

    @ParameterizedTest(name = "{0}")
    @MethodSource("goldenCases")
    void summary_passes_deterministic_checks_and_judge(String id, String product, List<String> reviews) {
        LlmClient client = client();
        String summary = new ReviewSummaryService(client).summarize(product, reviews);

        // 1) 결정론 검사: 규칙으로 잡히는 것은 판사 없이 먼저 자른다
        assertThat(summary.strip().split("\n")).as("3문장").hasSize(3);
        assertThat(PII.matcher(summary).find()).as("개인정보 포함: " + summary).isFalse();

        // 2) LLM 판사: 충실성·균형·어조
        LlmJudge.Verdict v = new LlmJudge(client).judge(reviews, summary);
        assertThat(v.pass())
                .as("판사 실패 %s: %s%n요약: %s", v.failed(), v.reasons(), summary)
                .isTrue();
    }
}
