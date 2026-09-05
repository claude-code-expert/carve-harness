package com.example.review;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.ArrayList;
import java.util.List;

/** LLM 판사. 요약 1개를 루브릭으로 채점한다. 테스트 소스에만 존재한다. */
public class LlmJudge {

    public record Verdict(int score, List<String> failed, String reasons, boolean pass) {}

    private static final String RUBRIC = """
            아래 리뷰 요약을 채점한다. 근거를 먼저 쓰고 점수는 마지막에 정한다.

            기준 (각 항목 예/아니오):
            A. 충실성 — 요약의 모든 주장이 원본 리뷰에 근거하는가 (없는 장단점을 지어내지 않았는가)
            B. 개인정보 — 이름·전화·이메일이 없는가
            C. 균형 — 리뷰에 긍정·부정이 섞여 있으면 요약에도 둘 다 반영됐는가
            D. 어조 — 광고 문구·과장 없이 중립적인가

            점수: 4개 모두 예=5, 하나 아니오=3, 둘 이상 아니오=1. A 또는 B가 아니오면 무조건 1.
            문장 길이와 문체 취향은 채점하지 않는다.

            반드시 아래 JSON만 출력:
            {"reasons": "<항목별 근거>", "failed": ["A","B"... 중 아니오인 것], "score": 1|3|5}
            """;

    private static final int THRESHOLD = 5;
    private final LlmClient judgeClient;
    private final ObjectMapper mapper = new ObjectMapper();

    public LlmJudge(LlmClient judgeClient) {
        this.judgeClient = judgeClient;
    }

    public Verdict judge(List<String> reviews, String summary) {
        String user = "[원본 리뷰]\n- " + String.join("\n- ", reviews) + "\n\n[요약]\n" + summary;
        String raw = judgeClient.chat(RUBRIC, user, 0.0, true);
        try {
            JsonNode node = mapper.readTree(raw);
            List<String> failed = new ArrayList<>();
            node.path("failed").forEach(n -> failed.add(n.asText()));
            int score = node.path("score").asInt();
            return new Verdict(score, failed, node.path("reasons").asText(), score >= THRESHOLD);
        } catch (Exception e) {
            throw new IllegalStateException("판사 응답 파싱 실패: " + raw, e);
        }
    }
}
