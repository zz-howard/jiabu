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
    assert!(breaker.claim(now, &cfg));
    breaker.finish(false, now, &cfg);
    assert!(!breaker.claim(now + Duration::from_secs(59), &cfg));
    assert!(breaker.claim(now + Duration::from_secs(60), &cfg));
    assert!(!breaker.claim(now + Duration::from_secs(60), &cfg));
    breaker.finish(true, now + Duration::from_secs(61), &cfg);
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
    req.provider_blobs.push(ProviderBlob {
        provider_id: "fake-1".into(),
        model: "model-1".into(),
        account_id: "synthetic-account".into(),
        item: serde_json::json!({"type":"reasoning","encrypted_content":"synthetic-opaque"}),
    });
    let meter = Meter::default();
    router
        .run_turn(TaskKind::Chat, &req, &mut Sink::default(), &meter)
        .await
        .unwrap();
    let requests = mock.requests();
    assert_eq!(requests.len(), 2);
    assert!(!requests[0].provider_blobs.is_empty());
    assert!(requests[1].provider_blobs.is_empty());
    assert_eq!(requests[1].items.len(), requests[0].items.len() + 1);
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
    req.provider_blobs.push(ProviderBlob {
        provider_id: "fake-1".into(),
        model: "model-1".into(),
        account_id: "synthetic-account".into(),
        item: serde_json::json!({}),
    });
    assert_eq!(
        router
            .run_turn(
                TaskKind::Chat,
                &req,
                &mut Sink::default(),
                &Meter::default()
            )
            .await,
        Err(ProviderError::BlobRejected)
    );
    assert_eq!(mock.requests().len(), 2);
}
