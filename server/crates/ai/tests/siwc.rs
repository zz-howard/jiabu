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
    let mut req = request();
    req.items.push(RequestItem::ProviderBlob(ProviderBlob {
        provider_id: "synthetic".into(),
        model: "synthetic-model".into(),
        account_id: "synthetic-account".into(),
        item: json!({"type":"reasoning","encrypted_content":"synthetic-opaque","summary":[]}),
    }));
    req.items.push(RequestItem::ToolCall {
        call_id: "synthetic-call".into(),
        name: "jiabu.create_record".into(),
        args_raw: "{ \"amount\": 50 }".into(),
    });
    req.items.push(RequestItem::ToolResult {
        call_id: "synthetic-call".into(),
        output: "synthetic-result".into(),
    });
    let body = body(&req, "synthetic", "synthetic-account").unwrap();
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
        },
        {
          "encrypted_content": "synthetic-opaque",
          "summary": [],
          "type": "reasoning"
        },
        {
          "arguments": "{ \"amount\": 50 }",
          "call_id": "synthetic-call",
          "name": "create_record",
          "namespace": "jiabu",
          "type": "function_call"
        },
        {
          "call_id": "synthetic-call",
          "output": "synthetic-result",
          "type": "function_call_output"
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
    let user = body(&req, "synthetic", "synthetic-account").unwrap()["input"][0].clone();
    let first = json!({"type":"reasoning","encrypted_content":"first-opaque","summary":[]});
    let second = json!({"type":"reasoning","encrypted_content":"second-opaque","summary":[]});
    for (provider, model, account, item) in [
        ("other", "synthetic-model", "synthetic-account", json!({})),
        (
            "synthetic",
            "synthetic-model",
            "synthetic-account",
            first.clone(),
        ),
        ("synthetic", "other-model", "synthetic-account", json!({})),
        (
            "synthetic",
            "synthetic-model",
            "synthetic-account",
            second.clone(),
        ),
        ("synthetic", "synthetic-model", "other-account", json!({})),
    ] {
        req.items.push(RequestItem::ProviderBlob(ProviderBlob {
            provider_id: provider.into(),
            model: model.into(),
            account_id: account.into(),
            item,
        }));
        req.items.push(RequestItem::Message {
            role: "assistant".into(),
            text: format!("after {provider}/{model}/{account}"),
            images: vec![],
        });
    }
    let messages: Vec<_> = req
        .items
        .iter()
        .filter_map(|item| match item {
            RequestItem::Message { text, role, .. } if role == "assistant" => {
                Some(json!({"role":role,"content":[{"type":"input_text","text":text}]}))
            }
            _ => None,
        })
        .collect();
    assert_eq!(
        body(&req, "synthetic", "synthetic-account").unwrap()["input"],
        json!([
            user,
            messages[0],
            first,
            messages[1],
            messages[2],
            second,
            messages[3],
            messages[4]
        ])
    );
}

#[test]
fn three_tool_loops_preserve_each_complete_request_input_as_a_prefix() {
    let mut req = request();
    let mut previous = body(&req, "synthetic", "synthetic-account").unwrap()["input"]
        .as_array()
        .unwrap()
        .clone();
    for round in 1..=3 {
        let call_id = format!("synthetic-call-{round}");
        let args_raw = format!("{{ \"amount\": {round} }}");
        let output = format!("synthetic-result-{round}");
        let blob = json!({"type":"reasoning","encrypted_content":format!("synthetic-opaque-{round}"),"summary":[]});
        // Append model output and recorded tool results in journal order: F, O, B.
        req.items.push(RequestItem::ToolCall {
            call_id: call_id.clone(),
            name: "jiabu.create_record".into(),
            args_raw: args_raw.clone(),
        });
        req.items.push(RequestItem::ToolResult {
            call_id: call_id.clone(),
            output: output.clone(),
        });
        req.items.push(RequestItem::ProviderBlob(ProviderBlob {
            provider_id: "synthetic".into(),
            model: "synthetic-model".into(),
            account_id: "synthetic-account".into(),
            item: blob.clone(),
        }));
        let rendered = body(&req, "synthetic", "synthetic-account").unwrap();
        let input = rendered["input"].as_array().unwrap();
        assert!(
            input.starts_with(&previous),
            "request after tool loop {round}"
        );
        assert_eq!(input.len(), 1 + 3 * round);
        assert_eq!(
            &input[previous.len()..],
            &[
                json!({"type":"function_call","call_id":call_id,"namespace":"jiabu","name":"create_record","arguments":args_raw}),
                json!({"type":"function_call_output","call_id":call_id,"output":output}),
                blob,
            ]
        );
        previous = input.clone();
    }
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
    req.items.push(RequestItem::ProviderBlob(ProviderBlob {
        provider_id: "synthetic".into(),
        model: "synthetic-model".into(),
        account_id: "synthetic-account".into(),
        item: json!({"type":"reasoning","encrypted_content":"synthetic-opaque","summary":[]}),
    }));
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

#[tokio::test]
async fn access_token_errors_refresh_once_but_only_token_endpoint_rejection_revokes() {
    for (status, events, refresh_rejected, second_rejected) in [
        (
            200,
            vec![json!({"type":"error","code":"token_expired"})],
            false,
            false,
        ),
        (401, vec![], false, false),
        (
            200,
            vec![json!({"type":"error","code":"token_expired"})],
            true,
            false,
        ),
        (401, vec![], false, true),
    ] {
        let server = MockServer::start().await;
        let tokens = Tokens::new(chrono::Utc::now().timestamp() + 3600);
        let manager = Arc::new(
            CredentialManager::new(tokens.clone(), OAuthClient::at(&server.uri()).unwrap()).await,
        );
        Mock::given(method("POST"))
            .and(path("/v1/responses"))
            .and(header("authorization", "Bearer synthetic-access"))
            .respond_with(ResponseTemplate::new(status).set_body_string(sse(&events)))
            .expect(1)
            .mount(&server)
            .await;
        let refresh = if refresh_rejected {
            ResponseTemplate::new(400).set_body_json(json!({"error":"invalid_grant"}))
        } else {
            ResponseTemplate::new(200).set_body_json(json!({
                "access_token":"synthetic-new-access", "refresh_token":"synthetic-new-refresh",
                "expires_in":3600, "token_type":"Bearer"
            }))
        };
        Mock::given(method("POST"))
            .and(path("/oauth/token"))
            .respond_with(refresh)
            .expect(1)
            .mount(&server)
            .await;
        Mock::given(method("POST"))
            .and(path("/v1/responses"))
            .and(header("authorization", "Bearer synthetic-new-access"))
            .respond_with(if second_rejected {
                ResponseTemplate::new(401)
            } else {
                ResponseTemplate::new(200).set_body_string(sse(&[completed()]))
            })
            .expect(if refresh_rejected { 0 } else { 1 })
            .mount(&server)
            .await;
        let provider = SiwcProvider::at(
            "synthetic".into(),
            capabilities(),
            manager.clone(),
            &format!("{}/v1/responses", server.uri()),
        )
        .unwrap();
        let mut sink = Sink::default();
        let meter = Meter::default();
        let result = provider
            .run_turn_observed(
                TaskKind::Chat,
                &request(),
                &mut sink,
                &meter,
                std::time::Duration::from_secs(30),
            )
            .await;
        let expected = if refresh_rejected {
            vec![Some("auth".to_owned())]
        } else {
            vec![
                Some("auth".to_owned()),
                second_rejected.then(|| "auth".to_owned()),
            ]
        };
        assert_eq!(*meter.results.lock().unwrap(), expected);
        assert_eq!(
            meter.calls.lock().unwrap().len(),
            if refresh_rejected { 1 } else { 2 }
        );
        if refresh_rejected || second_rejected {
            assert_eq!(result, Err(ProviderError::Auth));
            assert!(sink.0.is_empty());
        } else {
            result.unwrap();
            assert!(matches!(sink.0.last(), Some(TurnEvent::Done { .. })));
        }
        assert_eq!(tokens.snapshot().await.usable, !refresh_rejected);
        assert_eq!(manager.available(), !refresh_rejected);
        if second_rejected {
            assert_eq!(
                manager.access().await.unwrap().access_token,
                "synthetic-new-access"
            );
        }
    }
}

#[tokio::test]
async fn forbidden_errors_do_not_refresh_or_change_credentials() {
    for (code, expected) in [
        (
            "permission_denied",
            ProviderError::Unsupported("permission denied"),
        ),
        (
            "insufficient_permissions",
            ProviderError::Unsupported("permission denied"),
        ),
        (
            "model_not_found",
            ProviderError::Unsupported("permission denied"),
        ),
        (
            "model_access_denied",
            ProviderError::Unsupported("permission denied"),
        ),
        (
            "token_expired",
            ProviderError::Unsupported("permission denied"),
        ),
        ("unknown", ProviderError::Unsupported("permission denied")),
        ("insufficient_quota", ProviderError::QuotaExhausted),
        (
            "rate_limit_exceeded",
            ProviderError::RateLimited { retry_after: None },
        ),
    ] {
        let server = MockServer::start().await;
        Mock::given(method("POST"))
            .and(path("/v1/responses"))
            .respond_with(ResponseTemplate::new(403).set_body_json(json!({"error":{"code":code}})))
            .expect(1)
            .mount(&server)
            .await;
        Mock::given(method("POST"))
            .and(path("/oauth/token"))
            .respond_with(ResponseTemplate::new(500))
            .expect(0)
            .mount(&server)
            .await;
        let tokens = Tokens::new(chrono::Utc::now().timestamp() + 3600);
        let manager = Arc::new(
            CredentialManager::new(tokens.clone(), OAuthClient::at(&server.uri()).unwrap()).await,
        );
        let provider = SiwcProvider::at(
            "synthetic".into(),
            capabilities(),
            manager.clone(),
            &format!("{}/v1/responses", server.uri()),
        )
        .unwrap();
        assert_eq!(
            provider.run_turn(&request(), &mut Sink::default()).await,
            Err(expected)
        );
        assert!(manager.available());
        let current = tokens.snapshot().await;
        assert!(current.usable);
        assert_eq!(current.revision, 1);
        assert_eq!(current.credentials.access_token, "synthetic-access");
    }
}

#[tokio::test]
async fn token_error_after_visible_text_does_not_replay_output_or_revoke_credentials() {
    let server = MockServer::start().await;
    Mock::given(method("POST"))
        .and(path("/v1/responses"))
        .respond_with(ResponseTemplate::new(200).set_body_string(sse(&[
            json!({"type":"response.output_text.delta","output_index":0,"delta":"Recorded."}),
            json!({"type":"error","code":"token_expired"}),
        ])))
        .expect(1)
        .mount(&server)
        .await;
    Mock::given(method("POST"))
        .and(path("/oauth/token"))
        .respond_with(ResponseTemplate::new(500))
        .expect(0)
        .mount(&server)
        .await;
    let tokens = Tokens::new(chrono::Utc::now().timestamp() + 3600);
    let manager = Arc::new(
        CredentialManager::new(tokens.clone(), OAuthClient::at(&server.uri()).unwrap()).await,
    );
    let provider = SiwcProvider::at(
        "synthetic".into(),
        capabilities(),
        manager.clone(),
        &format!("{}/v1/responses", server.uri()),
    )
    .unwrap();
    let mut sink = Sink::default();
    assert_eq!(
        provider.run_turn(&request(), &mut sink).await,
        Err(ProviderError::Auth)
    );
    assert_eq!(sink.0.len(), 1);
    assert!(matches!(&sink.0[0], TurnEvent::TextDelta(text) if text == "Recorded."));
    assert!(manager.available());
    assert!(tokens.snapshot().await.usable);
}

#[tokio::test]
async fn refusal_text_is_visible_with_or_without_deltas_and_is_not_duplicated() {
    for prefix in ["", "I cannot ", "I cannot help with that request."] {
        let server = MockServer::start().await;
        let mut events = vec![];
        if !prefix.is_empty() {
            events.push(json!({"type":"response.refusal.delta","output_index":0,"delta":prefix}));
        }
        events.push(json!({"type":"response.output_item.done","output_index":0,"item":{
            "type":"message","content":[{"type":"refusal","refusal":"I cannot help with that request."}]
        }}));
        events.push(completed());
        Mock::given(method("POST"))
            .respond_with(ResponseTemplate::new(200).set_body_string(sse(&events)))
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
            .filter_map(|event| match event {
                TurnEvent::TextDelta(text) => Some(text.as_str()),
                _ => None,
            })
            .collect();
        assert_eq!(text, "I cannot help with that request.");
        assert!(matches!(sink.0.last(), Some(TurnEvent::Done { .. })));
    }
}

#[tokio::test]
async fn completed_usage_reaches_observer_before_tool_call_sink_failure() {
    struct FailTool;
    #[async_trait::async_trait]
    impl TurnSink for FailTool {
        async fn emit(&mut self, event: TurnEvent) -> Result<(), ProviderError> {
            assert!(matches!(event, TurnEvent::ToolCall { .. }));
            Err(ProviderError::Sink)
        }
    }
    let server = MockServer::start().await;
    Mock::given(method("POST"))
        .respond_with(ResponseTemplate::new(200).set_body_string(sse(&[
            json!({"type":"response.output_item.done","output_index":0,"item":{
                "type":"function_call","call_id":"synthetic-call","name":"create_record","arguments":"{}"
            }}),
            completed(),
        ])))
        .expect(1)
        .mount(&server)
        .await;
    let meter = Meter::default();
    assert_eq!(
        provider(&server)
            .await
            .run_turn_observed(
                TaskKind::Chat,
                &request(),
                &mut FailTool,
                &meter,
                std::time::Duration::from_secs(30),
            )
            .await,
        Err(ProviderError::Sink)
    );
    let usage = meter.usages.lock().unwrap();
    let usage = usage[0].as_ref().unwrap();
    assert_eq!(
        (
            usage.input_tokens,
            usage.output_tokens,
            usage.cached_input_tokens,
            usage.cache_write_tokens
        ),
        (100, 12, 60, 10)
    );
    assert_eq!(*meter.results.lock().unwrap(), vec![Some("sink".into())]);
}

#[tokio::test]
async fn concurrent_401_requests_refresh_once_and_both_retry_successfully() {
    let server = MockServer::start().await;
    let manager = Arc::new(
        CredentialManager::new(
            Tokens::new(chrono::Utc::now().timestamp() + 3600),
            OAuthClient::at(&server.uri()).unwrap(),
        )
        .await,
    );
    // Overlap the initial requests so both receive 401 for the original token.
    let arrivals = Arc::new(std::sync::atomic::AtomicUsize::new(0));
    let count = arrivals.clone();
    Mock::given(path("/v1/responses"))
        .and(header("authorization", "Bearer synthetic-access"))
        .respond_with(move |_: &wiremock::Request| {
            count.fetch_add(1, std::sync::atomic::Ordering::SeqCst);
            ResponseTemplate::new(401).set_delay(std::time::Duration::from_millis(50))
        })
        .expect(2)
        .mount(&server)
        .await;
    let count = arrivals.clone();
    Mock::given(path("/oauth/token"))
        .respond_with(move |_: &wiremock::Request| {
            assert_eq!(count.load(std::sync::atomic::Ordering::SeqCst), 2);
            ResponseTemplate::new(200).set_body_json(json!({
                "access_token":"synthetic-new-access", "refresh_token":"synthetic-new-refresh",
                "expires_in":3600, "token_type":"Bearer"
            }))
        })
        .expect(1)
        .mount(&server)
        .await;
    Mock::given(path("/v1/responses"))
        .and(header("authorization", "Bearer synthetic-new-access"))
        .respond_with(ResponseTemplate::new(200).set_body_string(sse(&[completed()])))
        .expect(2)
        .mount(&server)
        .await;
    let provider = SiwcProvider::at(
        "synthetic".into(),
        capabilities(),
        manager,
        &format!("{}/v1/responses", server.uri()),
    )
    .unwrap();
    let req = request();
    let mut first = Sink::default();
    let mut second = Sink::default();
    let (a, b) = tokio::join!(
        provider.run_turn(&req, &mut first),
        provider.run_turn(&req, &mut second),
    );
    a.unwrap();
    b.unwrap();
    assert!(matches!(first.0.last(), Some(TurnEvent::Done { .. })));
    assert!(matches!(second.0.last(), Some(TurnEvent::Done { .. })));
}
