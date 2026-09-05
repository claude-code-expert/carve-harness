package com.example.review;

import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

/**
 * OpenAI 호환 /chat/completions 호출. OpenAI, 사내 vLLM 모두 base-url만 바꾸면 된다.
 * application.yml:
 *   llm.base-url: http://localhost:8000/v1
 *   llm.api-key: none
 *   llm.model: qwen3
 */
@Component
public class OpenAiCompatibleLlmClient implements LlmClient {

    private final RestClient restClient;
    private final String model;

    public OpenAiCompatibleLlmClient(
            @Value("${llm.base-url}") String baseUrl,
            @Value("${llm.api-key:none}") String apiKey,
            @Value("${llm.model}") String model) {
        this.restClient = RestClient.builder()
                .baseUrl(baseUrl)
                .defaultHeader("Authorization", "Bearer " + apiKey)
                .build();
        this.model = model;
    }

    @Override
    @SuppressWarnings("unchecked")
    public String chat(String systemPrompt, String userPrompt, double temperature, boolean jsonMode) {
        Map<String, Object> body = new java.util.HashMap<>();
        body.put("model", model);
        body.put("temperature", temperature);
        body.put("messages", List.of(
                Map.of("role", "system", "content", systemPrompt),
                Map.of("role", "user", "content", userPrompt)));
        if (jsonMode) {
            body.put("response_format", Map.of("type", "json_object"));
        }
        Map<String, Object> res = restClient.post()
                .uri("/chat/completions")
                .body(body)
                .retrieve()
                .body(Map.class);
        List<Map<String, Object>> choices = (List<Map<String, Object>>) res.get("choices");
        Map<String, Object> message = (Map<String, Object>) choices.get(0).get("message");
        return (String) message.get("content");
    }
}
