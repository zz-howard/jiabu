use super::*;
use std::collections::BTreeSet;

fn assert_schema_fields(value: &Value, schema: &str) -> Result<()> {
    let document = serde_json::to_value(crate::openapi())?;
    let properties = document["components"]["schemas"][schema]["properties"]
        .as_object()
        .ok_or_else(|| anyhow::anyhow!("missing properties for {schema}"))?;
    let object = value
        .as_object()
        .ok_or_else(|| anyhow::anyhow!("response is not an object"))?;
    assert_eq!(
        object.keys().collect::<BTreeSet<_>>(),
        properties.keys().collect::<BTreeSet<_>>(),
        "public fields must match {schema} exactly"
    );
    Ok(())
}

#[tokio::test]
async fn accepted_retry_survives_inviter_leave_but_not_space_deletion() -> Result<()> {
    let app = TestApp::new(false).await?;
    let owner_token = app.token().await?;
    let inviter = actor(&app, "inviter").await?;
    let invitee = actor(&app, "invitee").await?;
    let space = create(&app, &owner_token).await?;
    let inviter_invitation = invite(&app, &owner_token, space, "inviter", 1).await?;
    accept(&app, &inviter, inviter_invitation).await?;
    let invitation = invite(&app, &inviter.token, space, "invitee", 1).await?;
    let path = format!("/v1/me/invitations/{invitation}/accept");
    let key = Uuid::now_v7().to_string();
    let first = app
        .request(
            "POST",
            &path,
            Value::Null,
            Some(&invitee.token),
            &headers(&key, 1),
        )
        .await?;
    assert_eq!(first.status, StatusCode::OK);
    let member = Uuid::parse_str(
        first.json()["member_id"]
            .as_str()
            .ok_or_else(|| anyhow::anyhow!("missing member"))?,
    )?;
    // The successful response was lost by the client. Its inviter then leaves.
    assert_eq!(
        write(
            &app,
            &inviter.token,
            "POST",
            &format!("/v1/spaces/{space}/leave"),
            Value::Null,
            1
        )
        .await?
        .status,
        StatusCode::OK
    );
    let retry = app
        .request(
            "POST",
            &path,
            Value::Null,
            Some(&invitee.token),
            &headers(&key, 1),
        )
        .await?;
    assert_eq!(retry.status, StatusCode::OK);
    assert_eq!(retry.bytes, first.bytes);
    let owner = app.fixture.owner().await?;
    let version: i32 =
        sqlx::query_scalar("select version from space_members where space_id=$1 and id=$2")
            .bind(space)
            .bind(member)
            .fetch_one(&owner)
            .await?;
    assert_eq!(version, 1);
    let events: i64 = sqlx::query_scalar("select count(*) from space_events where space_id=$1 and subject_member_id=$2 and kind in ('join','rejoin')")
        .bind(space).bind(member).fetch_one(&owner).await?;
    assert_eq!(events, 1);
    // Make the invitee the sole remaining member and delete through the real API.
    assert_eq!(
        write(
            &app,
            &owner_token,
            "POST",
            &format!("/v1/spaces/{space}/transfer-ownership"),
            json!({"member_id":member}),
            1
        )
        .await?
        .status,
        StatusCode::OK
    );
    assert_eq!(
        write(
            &app,
            &owner_token,
            "POST",
            &format!("/v1/spaces/{space}/leave"),
            Value::Null,
            1
        )
        .await?
        .status,
        StatusCode::OK
    );
    assert_eq!(
        write(
            &app,
            &invitee.token,
            "DELETE",
            &format!("/v1/spaces/{space}"),
            json!({"name":"示例共享空间"}),
            1
        )
        .await?
        .status,
        StatusCode::OK
    );
    let retry = app
        .request(
            "POST",
            &path,
            Value::Null,
            Some(&invitee.token),
            &headers(&key, 1),
        )
        .await?;
    assert_eq!(retry.status, StatusCode::NOT_FOUND);
    assert_eq!(retry.json()["code"], "not_found");
    owner.close().await;
    Ok(())
}

#[tokio::test]
async fn patch_and_version_conflict_only_expose_public_fields() -> Result<()> {
    let app = TestApp::new(false).await?;
    let token = app.token().await?;
    let space = create(&app, &token).await?;
    for (path, body, schema) in [
        (
            format!("/v1/spaces/{space}"),
            json!({"name":"示例新名","expected_version":1}),
            "SpaceMetadata",
        ),
        (
            format!("/v1/spaces/{space}/members/me"),
            json!({"display_name":"示例显示名","expected_version":1}),
            "SpaceMember",
        ),
    ] {
        let success = write(&app, &token, "PATCH", &path, body.clone(), 1).await?;
        assert_eq!(success.status, StatusCode::OK);
        let success_body = success.json();
        assert_schema_fields(&success_body, schema)?;
        let conflict = write(&app, &token, "PATCH", &path, body, 1).await?;
        assert_eq!(conflict.status, StatusCode::CONFLICT);
        let problem = conflict.json();
        assert_eq!(problem["code"], "version_conflict");
        assert_schema_fields(&problem["current"], schema)?;
        assert_eq!(problem["current"]["version"], 2);
        for value in [&success_body, &problem["current"]] {
            for internal in [
                "created_by_user_id",
                "deleted_at",
                "created_at",
                "updated_at",
                "space_id",
                "user_id",
            ] {
                assert!(value.get(internal).is_none(), "leaked {schema}.{internal}");
            }
        }
    }
    Ok(())
}

#[test]
fn openapi_uses_specific_space_component_names() -> Result<()> {
    let document = serde_json::to_value(crate::openapi())?;
    let schemas = &document["components"]["schemas"];
    for old in [
        "Create",
        "Delete",
        "Rename",
        "Transfer",
        "Invite",
        "DisplayName",
        "Member",
        "Space",
        "Modules",
        "Spaces",
        "Invitation",
        "Invitations",
        "MemberSummary",
        "ReceivedInvitation",
        "ReceivedInvitations",
        "StateResponse",
        "Ownership",
    ] {
        assert!(
            schemas.get(old).is_none(),
            "generic component remains: {old}"
        );
    }
    for (path, method, schema) in [
        ("/v1/spaces", "post", "CreateSpaceRequest"),
        ("/v1/spaces/{space_id}", "patch", "RenameSpaceRequest"),
        ("/v1/spaces/{space_id}", "delete", "DeleteSpaceRequest"),
        ("/v1/spaces/{space_id}/invitations", "post", "InviteRequest"),
        (
            "/v1/spaces/{space_id}/transfer-ownership",
            "post",
            "TransferOwnershipRequest",
        ),
        (
            "/v1/spaces/{space_id}/members/me",
            "patch",
            "UpdateDisplayNameRequest",
        ),
    ] {
        assert!(schemas[schema].is_object(), "missing {schema}");
        assert_eq!(
            document["paths"][path][method]["requestBody"]["content"]["application/json"]["schema"]
                ["$ref"],
            format!("#/components/schemas/{schema}")
        );
    }
    for (path, method, status, schema) in [
        ("/v1/spaces", "get", "200", "SpacesResponse"),
        ("/v1/spaces", "post", "201", "SpaceMetadata"),
        ("/v1/spaces/{space_id}", "patch", "200", "SpaceMetadata"),
        (
            "/v1/spaces/{space_id}/members/me",
            "patch",
            "200",
            "SpaceMember",
        ),
        (
            "/v1/spaces/{space_id}/invitations",
            "get",
            "200",
            "SpaceInvitationsResponse",
        ),
        (
            "/v1/spaces/{space_id}/invitations",
            "post",
            "201",
            "SpaceInvitationResponse",
        ),
        (
            "/v1/spaces/{space_id}/transfer-ownership",
            "post",
            "200",
            "TransferOwnershipResponse",
        ),
        (
            "/v1/me/invitations",
            "get",
            "200",
            "ReceivedSpaceInvitationsResponse",
        ),
        (
            "/v1/me/invitations/{inv_id}/accept",
            "post",
            "200",
            "SpaceActionResponse",
        ),
    ] {
        assert!(schemas[schema].is_object(), "missing {schema}");
        assert_eq!(
            document["paths"][path][method]["responses"][status]["content"]["application/json"]["schema"]
                ["$ref"],
            format!("#/components/schemas/{schema}")
        );
    }
    assert_eq!(
        schemas["SpaceInvitationsResponse"]["properties"]["invitations"]["items"]["$ref"],
        "#/components/schemas/SpaceInvitation"
    );
    Ok(())
}

#[tokio::test]
async fn invitation_list_identifies_invitees_with_only_documented_fields() -> Result<()> {
    let app = TestApp::new(false).await?;
    let token = app.token().await?;
    let space = create(&app, &token).await?;
    let list = app
        .request("GET", "/v1/spaces", Value::Null, Some(&token), &[])
        .await?
        .json();
    let inviter = space_entry(&list, space)?["member_id"].clone();
    let mut expected = Vec::new();
    for (username, status) in [
        ("pending-guest", "pending"),
        ("declined-guest", "declined"),
        ("cancelled-guest", "cancelled"),
        ("accepted-guest", "accepted"),
    ] {
        let guest = actor(&app, username).await?;
        let id = invite(&app, &token, space, username, 1).await?;
        match status {
            "declined" => {
                assert_eq!(
                    write(
                        &app,
                        &guest.token,
                        "POST",
                        &format!("/v1/me/invitations/{id}/decline"),
                        Value::Null,
                        1
                    )
                    .await?
                    .status,
                    StatusCode::OK
                );
            }
            "cancelled" => {
                assert_eq!(
                    write(
                        &app,
                        &token,
                        "POST",
                        &format!("/v1/spaces/{space}/invitations/{id}/cancel"),
                        Value::Null,
                        1
                    )
                    .await?
                    .status,
                    StatusCode::OK
                );
            }
            "accepted" => {
                accept(&app, &guest, id).await?;
            }
            _ => {}
        }
        expected.push((id, username, status));
    }
    actor(&app, "hidden-guest").await?;
    let other = create(&app, &token).await?;
    invite(&app, &token, other, "hidden-guest", 1).await?;
    let reply = app
        .request(
            "GET",
            &format!("/v1/spaces/{space}/invitations"),
            Value::Null,
            Some(&token),
            &[],
        )
        .await?;
    assert_eq!(reply.status, StatusCode::OK);
    let body = reply.json();
    let rows = body["invitations"]
        .as_array()
        .ok_or_else(|| anyhow::anyhow!("no invitation list"))?;
    assert_eq!(rows.len(), expected.len());
    for (id, username, status) in expected {
        let row = rows
            .iter()
            .find(|row| row["id"] == id.to_string())
            .ok_or_else(|| anyhow::anyhow!("missing invitation"))?;
        assert_schema_fields(row, "SpaceInvitation")?;
        let fields: BTreeSet<_> = row
            .as_object()
            .ok_or_else(|| anyhow::anyhow!("bad invitation"))?
            .keys()
            .map(String::as_str)
            .collect();
        assert_eq!(
            fields,
            BTreeSet::from([
                "id",
                "status",
                "invitee_username",
                "invited_by_member_id",
                "created_at",
                "decided_at"
            ])
        );
        assert_eq!(row["invitee_username"], username);
        assert_eq!(row["status"], status);
        assert_eq!(row["invited_by_member_id"], inviter);
        assert!(row["created_at"].as_str().is_some());
        assert_eq!(row["decided_at"].is_null(), status == "pending");
    }
    // The test account exists, but neither its identity nor its other-space invitation is listed.
    assert!(
        rows.iter()
            .all(|row| row["invitee_username"] != "hidden-guest")
    );
    Ok(())
}
