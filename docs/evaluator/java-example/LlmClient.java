package com.example.review;

/** LLM 호출 1개. 서비스와 테스트(판사)가 같은 인터페이스를 쓰고, 테스트에서는 스텁으로 교체한다. */
public interface LlmClient {
    String chat(String systemPrompt, String userPrompt, double temperature, boolean jsonMode);
}
