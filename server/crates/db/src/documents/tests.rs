//! A multi-space read transaction makes explicit query predicates independently
//! testable: RLS permits both spaces here, so it cannot hide a missing predicate.
use super::*;
use crate::tests::support;
use crate::{AppDb, Mode};
use anyhow::Result;
#[tokio::test]
async fn explicit_space_predicates_hold_when_rls_allows_both_spaces() -> Result<()> {
    let fixture = support::TestDb::new().await?;
    let a = fixture.seed("fictional-alpha", "unused").await?;
    let b = fixture.seed("fictional-beta", "unused").await?;
    let owner = fixture.owner().await?;
    let member_a: Uuid = sqlx::query_scalar("select id from space_members where space_id=$1")
        .bind(a.space_id.0)
        .fetch_one(&owner)
        .await?;
    let member_b:Uuid=sqlx::query_scalar("insert into space_members(space_id,user_id,display_name,role,status,joined_at,change_seq) values($1,$2,'fictional-alpha','member','active',now(),nextval('change_seq')) returning id").bind(b.space_id.0).bind(a.user_id.0).fetch_one(&owner).await?;
    sqlx::query("insert into space_member_grants(member_id,module,level,change_seq) values($1,'documents','write',nextval('change_seq'))").bind(member_b).execute(&owner).await?;
    let sa = Uuid::now_v7();
    let sb = Uuid::now_v7();
    let da = Uuid::now_v7();
    let db_id = Uuid::now_v7();
    for (space, member, id) in [(a.space_id.0, member_a, sa), (b.space_id.0, member_b, sb)] {
        sqlx::query("insert into subjects(id,space_id,kind,name,created_by_member_id,change_seq,created_at,updated_at) values($1,$2,'family_member','虚构对象',$3,nextval('change_seq'),now(),now())").bind(id).bind(space).bind(member).execute(&owner).await?;
    }
    let content = serde_json::json!({"v":1,"items":[{"key":"weight","type":"number","label":"虚构体重","value":60,"unit":"kg","metric":"body.weight"}]});
    for (space, member, id) in [
        (a.space_id.0, member_a, da),
        (b.space_id.0, member_b, db_id),
    ] {
        // Deliberately adversarial array in B, supplied via the owner fixture only:
        // the application's subject validation must never create this association.
        sqlx::query("insert into documents(id,space_id,template_id,template_version,title,event_date,subject_ids,content,origin,created_by_member_id,updated_by_member_id,change_seq,created_at,updated_at) values($1,$2,'jiabu.checkup',1,'虚构资料','2026-10-12',$3,$4,'api',$5,$5,nextval('change_seq'),now(),now())")
            .bind(id).bind(space).bind(vec![sa]).bind(&content).bind(member).execute(&owner).await?;
    }
    let db = AppDb::connect(&fixture.app_url).await?;
    let tx = SpaceTx::begin(
        &db,
        a.user_id,
        &[(a.space_id, None), (b.space_id, None)],
        Mode::Read,
    )
    .await?;
    assert_eq!(
        tx.documents_get(a.space_id, GetDocument { id: db_id })
            .await
            .unwrap_err()
            .code,
        "not_found"
    );
    assert_eq!(
        tx.documents_subject(a.space_id, sb).await.unwrap_err().code,
        "not_found"
    );
    let found = tx
        .documents_search(a.space_id, serde_json::from_value(serde_json::json!({}))?)
        .await?;
    assert_eq!(found.documents.len(), 1);
    assert_eq!(found.documents[0].id, da);
    let list = tx
        .documents_list_subjects(a.space_id, serde_json::from_value(serde_json::json!({}))?)
        .await?;
    assert_eq!(list.subjects.len(), 1);
    assert_eq!(list.subjects[0].id, sa);
    let template: Template = serde_json::from_str(jiabu_domain::templates::OFFICIAL[0].1)?;
    let declarations = BTreeMap::from([(template.id.clone(), template)]);
    let series = tx
        .documents_metric(
            a.space_id,
            MetricSeries {
                subject_id: sa,
                metric: "body.weight".into(),
                from: None,
                to: None,
            },
            &declarations,
        )
        .await?;
    assert_eq!(series.points.len(), 1);
    assert_eq!(series.points[0].document_id, da);
    tx.commit().await?;
    owner.close().await;
    db.close().await?;
    Ok(())
}
