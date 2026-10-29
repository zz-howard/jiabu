mod support;
use jiabu_ai::{
    mock::{MockProvider, MockStep},
    *,
};
use std::{
    sync::Arc,
    time::{Duration, Instant},
};
use support::*;
#[tokio::test]
async fn paid_fallback_disabled_never_calls_paid_mock_and_meters_each_actual_attempt() {
    let primary = Arc::new(MockProvider::scripted(
        "fake-1",
        capabilities(),
        vec![vec![MockStep::Fail(ProviderError::QuotaExhausted)]],
    ));
    let paid = Arc::new(MockProvider::scripted(
        "fake-2",
        capabilities(),
        vec![vec![MockStep::Emit(TurnEvent::Done {
            usage: Usage::default(),
        })]],
    ));
    let router = AiRouter::new(config(), vec![primary, paid.clone()]);
    let meter = Meter::default();
    assert_eq!(
        router
            .run_turn(TaskKind::Chat, &request(), &mut Sink::default(), &meter)
            .await,
        Err(ProviderError::QuotaExhausted)
    );
    assert!(paid.requests().is_empty());
    assert_eq!(meter.calls.lock().unwrap().len(), 1);
    let mut allowed = config();
    allowed.allow_paid_fallback = true;
    let router = router.reloaded(allowed, vec![paid.clone()]);
    router
        .run_turn(TaskKind::Chat, &request(), &mut Sink::default(), &meter)
        .await
        .unwrap();
    assert_eq!(paid.requests().len(), 1);
    assert_eq!(meter.calls.lock().unwrap().len(), 2);
}
#[test]
fn ai_available_only_looks_at_requested_chat_route() {
    let mock = Arc::new(MockProvider::scripted("fake-1", capabilities(), vec![]));
    let mut c = config();
    c.routes.retain(|r| r.model_id == uuid::Uuid::from_u128(1));
    c.routes[0].task_kind = TaskKind::ChatVision;
    let router = AiRouter::new(c, vec![mock]);
    assert!(!router.availability(TaskKind::Chat).available);
    assert!(router.availability(TaskKind::ChatVision).available);
}
#[tokio::test]
async fn reload_preserves_open_breaker_until_successful_single_half_open_probe() {
    let failed = Arc::new(MockProvider::scripted(
        "fake-1",
        capabilities(),
        vec![vec![MockStep::Fail(ProviderError::Transport)]; 3],
    ));
    let router = AiRouter::new(config(), vec![failed]);
    for _ in 0..3 {
        assert!(
            router
                .run_turn(
                    TaskKind::Chat,
                    &request(),
                    &mut Sink::default(),
                    &Meter::default()
                )
                .await
                .is_err()
        );
    }
    assert!(!router.availability(TaskKind::Chat).available);
    let fresh = Arc::new(MockProvider::scripted("fake-1", capabilities(), vec![]));
    let router = router.reloaded(config(), vec![fresh.clone()]);
    assert!(!router.availability(TaskKind::Chat).available);
    assert!(fresh.requests().is_empty());
    let mut breaker = jiabu_ai::breaker::Breaker::default();
    let now = Instant::now();
    let cfg = BreakerConfig {
        failures: 1,
        cool_down_secs: 60,
    };
    let permit = breaker.claim(now, &cfg).unwrap();
    breaker.finish(permit, false, now, &cfg);
    assert!(breaker.claim(now + Duration::from_secs(59), &cfg).is_none());
    let permit = breaker.claim(now + Duration::from_secs(60), &cfg).unwrap();
    assert!(breaker.claim(now + Duration::from_secs(60), &cfg).is_none());
    breaker.finish(permit, true, now + Duration::from_secs(61), &cfg);
    assert!(breaker.available(now + Duration::from_secs(61), &cfg));
}
#[tokio::test]
async fn encrypted_blob_rejection_retries_once_without_blob_with_independent_meter() {
    let mock = Arc::new(MockProvider::scripted(
        "fake-1",
        capabilities(),
        vec![
            vec![MockStep::Fail(ProviderError::BlobRejected)],
            vec![MockStep::Emit(TurnEvent::Done {
                usage: Usage::default(),
            })],
        ],
    ));
    let router = AiRouter::new(config(), vec![mock.clone()]);
    let mut req = request();
    req.items.push(RequestItem::ProviderBlob(ProviderBlob {
        provider_id: "fake-1".into(),
        model: "model-1".into(),
        account_id: "synthetic-account".into(),
        item: serde_json::json!({"type":"reasoning","encrypted_content":"synthetic-opaque"}),
    }));
    req.items.push(RequestItem::ToolCall {
        call_id: "synthetic-call".into(),
        name: "jiabu.create_record".into(),
        args_raw: "{}".into(),
    });
    req.items.push(RequestItem::ProviderBlob(ProviderBlob {
        provider_id: "other-provider".into(),
        model: "other-model".into(),
        account_id: "other-account".into(),
        item: serde_json::json!({"type":"reasoning","encrypted_content":"other-opaque"}),
    }));
    req.items.push(RequestItem::ToolResult {
        call_id: "synthetic-call".into(),
        output: "synthetic-result".into(),
    });
    let meter = Meter::default();
    router
        .run_turn(TaskKind::Chat, &req, &mut Sink::default(), &meter)
        .await
        .unwrap();
    let requests = mock.requests();
    assert_eq!(requests.len(), 2);
    let original = &requests[0].items;
    let retry = &requests[1].items;
    assert_eq!(
        original
            .iter()
            .filter(|item| matches!(item, RequestItem::ProviderBlob(_)))
            .count(),
        2
    );
    assert!(
        !retry
            .iter()
            .any(|item| matches!(item, RequestItem::ProviderBlob(_)))
    );
    let retained: Vec<_> = original
        .iter()
        .filter(|item| !matches!(item, RequestItem::ProviderBlob(_)))
        .collect();
    assert_eq!(retry.len(), retained.len() + 1);
    assert_eq!(
        serde_json::to_value(&retry[..retained.len()]).unwrap(),
        serde_json::to_value(&retained).unwrap()
    );
    assert!(matches!(retry.last(), Some(RequestItem::Message { role, .. }) if role == "developer"));
    // The caller's history is unchanged by the retry.
    assert_eq!(
        serde_json::to_value(&req.items).unwrap(),
        serde_json::to_value(original).unwrap()
    );
    assert_eq!(meter.calls.lock().unwrap().len(), 2);
}
#[tokio::test]
async fn a_second_blob_rejection_does_not_loop() {
    let mock = Arc::new(MockProvider::scripted(
        "fake-1",
        capabilities(),
        vec![vec![MockStep::Fail(ProviderError::BlobRejected)]; 3],
    ));
    let router = AiRouter::new(config(), vec![mock.clone()]);
    let mut req = request();
    req.items.push(RequestItem::ProviderBlob(ProviderBlob {
        provider_id: "fake-1".into(),
        model: "model-1".into(),
        account_id: "synthetic-account".into(),
        item: serde_json::json!({}),
    }));
    assert_eq!(
        router
            .run_turn(
                TaskKind::Chat,
                &req,
                &mut Sink::default(),
                &Meter::default()
            )
            .await,
        Err(ProviderError::PartialOutput {
            source: Box::new(ProviderError::BlobRejected)
        })
    );
    assert_eq!(mock.requests().len(), 2);
}

#[tokio::test]
async fn visible_output_prevents_both_retry_and_fallback() {
    for event in [
        TurnEvent::TextDelta("已记录。".into()),
        TurnEvent::ToolCall {
            call_id: "synthetic".into(),
            name: "fake".into(),
            args_raw: "{}".into(),
        },
    ] {
        let primary = Arc::new(MockProvider::scripted(
            "fake-1",
            capabilities(),
            vec![vec![
                MockStep::Emit(event),
                MockStep::Fail(ProviderError::InvalidOutput),
            ]],
        ));
        let fallback = Arc::new(MockProvider::scripted("fake-2", capabilities(), vec![]));
        let mut cfg = config();
        cfg.allow_paid_fallback = true;
        let router = AiRouter::new(cfg, vec![primary.clone(), fallback.clone()]);
        let mut sink = Sink::default();
        assert_eq!(
            router
                .run_turn(TaskKind::Chat, &request(), &mut sink, &Meter::default())
                .await,
            Err(ProviderError::PartialOutput {
                source: Box::new(ProviderError::InvalidOutput)
            })
        );
        assert_eq!(sink.0.len(), 1);
        assert_eq!(primary.requests().len(), 1);
        assert!(fallback.requests().is_empty());
    }
}
#[tokio::test]
async fn failure_without_output_still_falls_back() {
    let primary = Arc::new(MockProvider::scripted(
        "fake-1",
        capabilities(),
        vec![vec![MockStep::Fail(ProviderError::Transport)]],
    ));
    let fallback = Arc::new(MockProvider::scripted(
        "fake-2",
        capabilities(),
        vec![vec![MockStep::Emit(TurnEvent::Done {
            usage: Usage::default(),
        })]],
    ));
    let mut cfg = config();
    cfg.allow_paid_fallback = true;
    let router = AiRouter::new(cfg, vec![primary.clone(), fallback.clone()]);
    router
        .run_turn(
            TaskKind::Chat,
            &request(),
            &mut Sink::default(),
            &Meter::default(),
        )
        .await
        .unwrap();
    assert_eq!(primary.requests().len(), 1);
    assert_eq!(fallback.requests().len(), 1);
}
#[tokio::test]
async fn rejected_request_neither_falls_back_nor_opens_the_breaker() {
    let rejected = || ProviderError::Rejected {
        code: "invalid_function_parameters".into(),
        param: "tools".into(),
        message: "synthetic".into(),
    };
    // More rejections than any breaker threshold.
    let primary = Arc::new(MockProvider::scripted(
        "fake-1",
        capabilities(),
        (0..10).map(|_| vec![MockStep::Fail(rejected())]).collect(),
    ));
    let fallback = Arc::new(MockProvider::scripted("fake-2", capabilities(), vec![]));
    let mut cfg = config();
    cfg.allow_paid_fallback = true;
    let router = AiRouter::new(cfg, vec![primary.clone(), fallback.clone()]);
    for _ in 0..10 {
        let error = router
            .run_turn(
                TaskKind::Chat,
                &request(),
                &mut Sink::default(),
                &Meter::default(),
            )
            .await
            .unwrap_err();
        assert_eq!(error, rejected());
    }
    assert_eq!(primary.requests().len(), 10);
    assert!(fallback.requests().is_empty());
    assert!(router.availability(TaskKind::Chat).available);
}
struct RejectNote;
#[async_trait::async_trait]
impl TurnSink for RejectNote {
    async fn emit(&mut self, _: TurnEvent) -> Result<(), ProviderError> {
        Err(ProviderError::Sink)
    }
}
#[tokio::test]
async fn half_open_note_sink_failure_and_cancelled_future_release_probe() {
    for cancel in [false, true] {
        let barrier = Arc::new(tokio::sync::Barrier::new(2));
        let probe = if cancel {
            vec![
                MockStep::Barrier(barrier.clone()),
                MockStep::Delay(Duration::from_secs(600)),
            ]
        } else {
            vec![MockStep::Fail(ProviderError::BlobRejected)]
        };
        let mock = Arc::new(MockProvider::scripted(
            "fake-1",
            capabilities(),
            vec![
                vec![MockStep::Fail(ProviderError::Transport)],
                probe,
                vec![MockStep::Emit(TurnEvent::Done {
                    usage: Usage::default(),
                })],
            ],
        ));
        let mut cfg = config();
        cfg.breaker = BreakerConfig {
            failures: 1,
            cool_down_secs: 1,
        };
        let router = Arc::new(AiRouter::new(cfg, vec![mock.clone()]));
        assert!(
            router
                .run_turn(
                    TaskKind::Chat,
                    &request(),
                    &mut Sink::default(),
                    &Meter::default()
                )
                .await
                .is_err()
        );
        tokio::time::sleep(Duration::from_secs(1)).await;
        let mut req = request();
        req.items.push(RequestItem::ProviderBlob(ProviderBlob {
            provider_id: "fake-1".into(),
            model: "model-1".into(),
            account_id: "synthetic".into(),
            item: serde_json::json!({}),
        }));
        if cancel {
            let task_router = router.clone();
            let task = tokio::spawn(async move {
                task_router
                    .run_turn(
                        TaskKind::Chat,
                        &req,
                        &mut Sink::default(),
                        &Meter::default(),
                    )
                    .await
            });
            barrier.wait().await;
            assert!(!router.availability(TaskKind::Chat).available);
            task.abort();
            assert!(task.await.unwrap_err().is_cancelled());
        } else {
            assert_eq!(
                router
                    .run_turn(TaskKind::Chat, &req, &mut RejectNote, &Meter::default())
                    .await,
                Err(ProviderError::PartialOutput {
                    source: Box::new(ProviderError::Sink)
                })
            );
        }
        assert!(!router.availability(TaskKind::Chat).available);
        tokio::time::sleep(Duration::from_secs(1)).await;
        assert!(router.availability(TaskKind::Chat).available);
        router
            .run_turn(
                TaskKind::Chat,
                &request(),
                &mut Sink::default(),
                &Meter::default(),
            )
            .await
            .unwrap();
        assert_eq!(mock.requests().len(), 3);
    }
}
#[test]
fn overdue_probe_is_reclaimed_and_old_completion_cannot_finish_replacement() {
    let mut breaker = jiabu_ai::breaker::Breaker::default();
    let cfg = BreakerConfig {
        failures: 1,
        cool_down_secs: 1,
    };
    let now = Instant::now();
    let first = breaker.claim(now, &cfg).unwrap();
    breaker.finish(first, false, now, &cfg);
    let old = breaker.claim(now + Duration::from_secs(1), &cfg).unwrap();
    let deadline = now + Duration::from_secs(1) + jiabu_ai::breaker::CALL_TIMEOUT;
    assert!(!breaker.available(deadline, &cfg));
    let next = breaker
        .claim(deadline + Duration::from_secs(1), &cfg)
        .unwrap();
    breaker.finish(old, true, deadline + Duration::from_secs(1), &cfg);
    assert!(!breaker.available(deadline + Duration::from_secs(1), &cfg));
    breaker.finish(next, true, deadline + Duration::from_secs(2), &cfg);
    assert!(breaker.available(deadline + Duration::from_secs(2), &cfg));
}

#[tokio::test]
async fn invalid_output_without_visible_events_still_retries_once() {
    let mock = Arc::new(MockProvider::scripted(
        "fake-1",
        capabilities(),
        vec![
            vec![MockStep::Fail(ProviderError::InvalidOutput)],
            vec![MockStep::Emit(TurnEvent::Done {
                usage: Usage::default(),
            })],
        ],
    ));
    let router = AiRouter::new(config(), vec![mock.clone()]);
    router
        .run_turn(
            TaskKind::Chat,
            &request(),
            &mut Sink::default(),
            &Meter::default(),
        )
        .await
        .unwrap();
    assert_eq!(mock.requests().len(), 2);
}

#[tokio::test(start_paused = true)]
async fn timeout_finishes_meter_and_retries_share_remaining_budget() {
    for retry in [false, true] {
        let script = if retry {
            vec![
                vec![
                    MockStep::Delay(Duration::from_secs(200)),
                    MockStep::Fail(ProviderError::InvalidOutput),
                ],
                vec![MockStep::Delay(Duration::from_secs(200))],
            ]
        } else {
            vec![vec![MockStep::Delay(Duration::from_secs(600))]]
        };
        let mock = Arc::new(MockProvider::scripted("fake-1", capabilities(), script));
        let router = AiRouter::new(config(), vec![mock]);
        let meter = Meter::default();
        let started = tokio::time::Instant::now();
        assert_eq!(
            router
                .run_turn(TaskKind::Chat, &request(), &mut Sink::default(), &meter)
                .await,
            Err(ProviderError::Timeout)
        );
        assert!(started.elapsed() >= jiabu_ai::breaker::CALL_TIMEOUT);
        assert!(started.elapsed() < jiabu_ai::breaker::CALL_TIMEOUT + Duration::from_secs(1));
        let calls = meter.calls.lock().unwrap();
        let results = meter.results.lock().unwrap();
        assert_eq!(calls.len(), if retry { 2 } else { 1 });
        assert_eq!(calls.len(), results.len());
        assert_eq!(results.last().unwrap().as_deref(), Some("timeout"));
    }
}
