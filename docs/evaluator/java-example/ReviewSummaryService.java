package com.example.review;

import java.util.List;
import org.springframework.stereotype.Service;

/** 검증 대상 기능: 상품 리뷰 여러 개를 3줄 요약. 흔한 커머스 LLM 기능 하나. */
@Service
public class ReviewSummaryService {

    private static final String SYSTEM = """
            너는 쇼핑몰 리뷰 요약기다. 주어진 리뷰에 실제로 나온 내용만 요약한다.
            리뷰에 없는 장단점을 지어내지 않는다. 개인정보(이름·전화·이메일)는 쓰지 않는다.
            중립적 어조로 정확히 3문장, 각 문장은 줄바꿈으로 구분한다.
            """;

    private final LlmClient llmClient;

    public ReviewSummaryService(LlmClient llmClient) {
        this.llmClient = llmClient;
    }

    public String summarize(String productName, List<String> reviews) {
        String joined = String.join("\n- ", reviews);
        String user = "[상품] " + productName + "\n[리뷰]\n- " + joined;
        return llmClient.chat(SYSTEM, user, 0.3, false);
    }
}
