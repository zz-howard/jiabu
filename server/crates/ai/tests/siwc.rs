mod support;
use jiabu_ai::{
    credentials::CredentialManager,
    siwc::{SiwcProvider, oauth::OAuthClient, request::body},
    *,
};
use serde_json::json;
use std::sync::Arc;
use support::*;
use wiremock::{
    Mock, MockServer, ResponseTemplate,
    matchers::{header, method, path},
};
async fn provider(server: &MockServer) -> SiwcProvider {
    let tokens = Tokens::new(chrono::Utc::now().timestamp() + 3600);
    let manager =
        Arc::new(CredentialManager::new(tokens, OAuthClient::at(&server.uri()).unwrap()).await);
    SiwcProvider::at(
        "synthetic".into(),
        capabilities(),
        manager,
        &format!("{}/v1/responses", server.uri()),
    )
    .unwrap()
}
#[test]
fn request_snapshot_is_allowlisted_with_namespace_image_and_no_forbidden_fields() {
    let body = body(&request(), "synthetic", "synthetic-account").unwrap();
    insta::assert_json_snapshot!(body, @r###"
    {
      "include": [
        "reasoning.encrypted_content"
      ],
      "input": [
        {
          "content": [
            {
              "text": "Synthetic receipt",
              "type": "input_text"
            },
            {
              "detail": "auto",
              "image_url": "data:image/jpeg;base64,/9j/2Q==",
              "type": "input_image"
            }
          ],
          "role": "user"
        }
      ],
      "instructions": "Use household tools.",
      "model": "synthetic-model",
      "prompt_cache_key": "00000000-0000-7000-8000-000000000001",
      "store": false,
      "stream": true,
      "tools": [
        {
          "description": "Jiabu household tools",
          "name": "jiabu",
          "tools": [
            {
              "description": "Create a synthetic record",
              "name": "create_record",
              "parameters": {
                "additionalProperties": false,
                "properties": {
                  "amount": {
                    "type": "integer"
                  }
                },
                "required": [
                  "amount"
                ],
                "type": "object"
              },
              "strict": true,
              "type": "function"
            }
          ],
          "type": "namespace"
        }
      ]
    }
    "###);
    for field in [
        "background",
        "conversation",
        "max_output_tokens",
        "max_tool_calls",
        "metadata",
        "moderation",
        "multi_agent",
        "prompt",
        "prompt_cache_retention",
        "safety_identifier",
        "temperature",
        "top_logprobs",
        "top_p",
        "truncation",
        "user",
        "previous_response_id",
        "prompt_cache_options",
        "prompt_cache_breakpoint",
    ] {
        assert!(body.get(field).is_none(), "{field}");
    }
}
#[tokio::test]
async fn wire_replay_uses_session_header_and_done_items_without_duplicate_delta() {
    let server = MockServer::start().await;
    let events = vec![
        json!({"type":"response.output_text.delta","output_index":0,"delta":"Recorded."}),
        json!({"type":"response.output_item.done","output_index":0,"item":{"type":"message","content":[{"type":"output_text","text":"Recorded."}]}}),
        json!({"type":"response.output_item.done","output_index":1,"item":{"type":"function_call","call_id":"synthetic-call","name":"create_record","arguments":"{ \"amount\": 50 }"}}),
        completed(),
    ];
    Mock::given(method("POST"))
        .and(path("/v1/responses"))
        .and(header("session_id", request().session_key.as_str()))
        .respond_with(
            ResponseTemplate::new(200)
                .insert_header("content-type", "text/event-stream")
                .set_body_string(sse(&events)),
        )
        .expect(1)
        .mount(&server)
        .await;
    let mut sink = Sink::default();
    provider(&server)
        .await
        .run_turn(&request(), &mut sink)
        .await
        .unwrap();
    let text: String = sink
        .0
        .iter()
        .filter_map(|e| {
            if let TurnEvent::TextDelta(t) = e {
                Some(t.as_str())
            } else {
                None
            }
        })
        .collect();
    assert_eq!(text, "Recorded.");
    assert!(sink.0.iter().any(|e|matches!(e,TurnEvent::ToolCall{call_id,name,args_raw} if call_id=="synthetic-call" && name=="jiabu.create_record" && args_raw=="{ \"amount\": 50 }")));
    assert!(
        matches!(sink.0.last(),Some(TurnEvent::Done{usage}) if usage.cached_input_tokens==60 && usage.cache_write_tokens==10)
    );
    let requests = server.received_requests().await.unwrap();
    let actual: serde_json::Value = serde_json::from_slice(&requests[0].body).unwrap();
    assert_eq!(actual["prompt_cache_key"], request().session_key);
    assert_eq!(actual["store"], false);
    assert_eq!(actual["stream"], true);
}
#[tokio::test]
async fn stream_quota_errors_and_missing_completed_never_emit_done_or_tool_calls() {
    for ending in [
        None,
        Some("subscription_sharing_usage_limit_exceeded"),
        Some("subscription_sharing_usage_unavailable"),
    ] {
        let server = MockServer::start().await;
        let mut events = vec![
            json!({"type":"response.output_item.done","output_index":0,"item":{"type":"function_call","call_id":"fake","name":"create_record","arguments":"{}"}}),
        ];
        if let Some(code) = ending {
            events.push(json!({"type":"response.failed","response":{"error":{"code":code}}}));
        }
        Mock::given(method("POST"))
            .respond_with(ResponseTemplate::new(200).set_body_string(sse(&events)))
            .mount(&server)
            .await;
        let mut sink = Sink::default();
        let error = provider(&server)
            .await
            .run_turn(&request(), &mut sink)
            .await
            .unwrap_err();
        assert_eq!(
            error,
            if ending.is_some() {
                ProviderError::QuotaExhausted
            } else {
                ProviderError::InvalidOutput
            }
        );
        assert!(sink.0.is_empty());
    }
}
#[tokio::test]
async fn decoder_handles_chunk_boundaries_crlf_and_done_only_text() {
    let wire=sse(&[json!({"type":"response.output_item.done","output_index":0,"item":{"type":"message","content":[{"type":"output_text","text":"合成文字"}]}}),completed()]).replace("\n","\r\n");
    let mut decoder = jiabu_ai::siwc::stream::Decoder::default();
    let mut state = jiabu_ai::siwc::stream::TurnState::default();
    let mut sink = Sink::default();
    for byte in wire.as_bytes() {
        for event in decoder.push(&[*byte]).unwrap() {
            state.accept(event, &mut sink).await.unwrap();
        }
    }
    state
        .finish("fake", "synthetic-model", "synthetic-account", &mut sink)
        .await
        .unwrap();
    assert!(matches!(&sink.0[0],TurnEvent::TextDelta(t) if t=="合成文字"));
}
#[test]
fn encrypted_reasoning_scope_is_provider_model_and_account_bound() {
    let mut req = request();
    req.provider_blobs.push(ProviderBlob {
        provider_id: "synthetic".into(),
        model: req.snapshot.model.clone(),
        account_id: "synthetic-account".into(),
        item: json!({"type":"reasoning","encrypted_content":"synthetic-opaque","summary":[]}),
    });
    assert_eq!(
        body(&req, "synthetic", "synthetic-account").unwrap()["input"]
            .as_array()
            .unwrap()
            .len(),
        2
    );
    for (provider, account) in [("other", "synthetic-account"), ("synthetic", "other")] {
        assert_eq!(
            body(&req, provider, account).unwrap()["input"]
                .as_array()
                .unwrap()
                .len(),
            1
        );
    }
    req.snapshot.model = "other-model".into();
    assert_eq!(
        body(&req, "synthetic", "synthetic-account").unwrap()["input"]
            .as_array()
            .unwrap()
            .len(),
        1
    );
}

#[tokio::test]
async fn wire_blob_rejection_removes_encrypted_item_once_and_records_two_attempts() {
    use wiremock::matchers::body_string_contains;
    let server = MockServer::start().await;
    Mock::given(method("POST"))
        .and(body_string_contains("synthetic-opaque"))
        .respond_with(
            ResponseTemplate::new(400)
                .set_body_json(json!({"error":{"code":"invalid_encrypted_content"}})),
        )
        .with_priority(1)
        .expect(1)
        .mount(&server)
        .await;
    Mock::given(method("POST"))
        .respond_with(ResponseTemplate::new(200).set_body_string(sse(&[completed()])))
        .with_priority(10)
        .expect(1)
        .mount(&server)
        .await;
    let mut config = config();
    config.providers[0].id = "synthetic".into();
    config.models[0].provider_id = "synthetic".into();
    config.models[0].model = "synthetic-model".into();
    let router = AiRouter::new(config, vec![Arc::new(provider(&server).await)]);
    let mut req = request();
    req.provider_blobs.push(ProviderBlob {
        provider_id: "synthetic".into(),
        model: "synthetic-model".into(),
        account_id: "synthetic-account".into(),
        item: json!({"type":"reasoning","encrypted_content":"synthetic-opaque","summary":[]}),
    });
    let meter = Meter::default();
    let mut sink = Sink::default();
    router
        .run_turn(TaskKind::Chat, &req, &mut sink, &meter)
        .await
        .unwrap();
    assert_eq!(meter.calls.lock().unwrap().len(), 2);
    assert!(sink.0.iter().any(|e| matches!(e, TurnEvent::Note(_))));
    let requests = server.received_requests().await.unwrap();
    assert_eq!(requests.len(), 2);
    assert!(!String::from_utf8_lossy(&requests[1].body).contains("synthetic-opaque"));
}
#[test]
fn history_replay_preserves_raw_arguments_and_frozen_model_parameters() {
    let mut req = request();
    req.items.push(RequestItem::ToolCall {
        call_id: "fake-call".into(),
        name: "jiabu.create_record".into(),
        args_raw: "{ \"amount\": 50 }".into(),
    });
    req.snapshot.parameters.reasoning_effort = Some("low".into());
    req.snapshot.parameters.verbosity = Some("low".into());
    req.snapshot.parameters.tool_choice = Some("auto".into());
    let body = body(&req, "synthetic", "synthetic-account").unwrap();
    assert_eq!(body["input"][1]["arguments"], "{ \"amount\": 50 }");
    assert_eq!(body["input"][1]["namespace"], "jiabu");
    assert_eq!(body["input"][1]["name"], "create_record");
    assert_eq!(body["reasoning"]["effort"], "low");
    assert_eq!(body["text"]["verbosity"], "low");
}
