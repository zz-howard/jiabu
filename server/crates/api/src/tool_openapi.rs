//! Registry schemas are also the public API schemas. No second DTO definitions.
use jiabu_tools::{Effect, Exposure, ToolRegistry};
use serde_json::{Map, Value, json};

type SchemaResult<T> = Result<T, serde_json::Error>;
const SYNC_OPERATION: &str = "SyncPushOperation";
const ENVELOPE_REF: &str = "#/components/schemas/PushOpEnvelope";
const BLOBS_PATH: &str = "/v1/spaces/{space_id}/blobs/{sha256}";

fn schema_error(message: impl std::fmt::Display) -> serde_json::Error {
    <serde_json::Error as serde::de::Error>::custom(message)
}

fn pointer_segment(segment: &str) -> String {
    segment.replace('~', "~0").replace('/', "~1")
}

fn object_at_mut<'a>(
    doc: &'a mut Value,
    pointer: &str,
) -> SchemaResult<&'a mut Map<String, Value>> {
    doc.pointer_mut(pointer)
        .and_then(Value::as_object_mut)
        .ok_or_else(|| schema_error(format!("expected an existing object at {pointer}")))
}

fn typed_schema_at_mut<'a>(
    doc: &'a mut Value,
    pointer: &str,
    expected: &str,
) -> SchemaResult<&'a mut Map<String, Value>> {
    let schema = object_at_mut(doc, pointer)?;
    if schema.contains_key("$ref") || schema.get("type").and_then(Value::as_str) != Some(expected) {
        return Err(schema_error(format!(
            "expected an inline {expected} schema at {pointer}"
        )));
    }
    Ok(schema)
}

fn insert_component(doc: &mut Value, name: &str, schema: Value) -> SchemaResult<()> {
    let schemas = object_at_mut(doc, "/components/schemas")?;
    if schemas.contains_key(name) {
        return Err(schema_error(format!(
            "generated component collides with existing schema: {name}"
        )));
    }
    schemas.insert(name.to_owned(), schema);
    Ok(())
}

fn rewrite_refs(value: &mut Value, prefix: &str) {
    match value {
        Value::Object(fields) => {
            if let Some(Value::String(reference)) = fields.get_mut("$ref")
                && let Some(name) = reference.strip_prefix("#/$defs/")
            {
                *reference = format!("#/components/schemas/{prefix}_{name}");
            }
            for child in fields.values_mut() {
                rewrite_refs(child, prefix);
            }
        }
        Value::Array(values) => {
            for child in values {
                rewrite_refs(child, prefix);
            }
        }
        _ => (),
    }
}

// utoipa cannot read back an unconstrained schema serialized as true, {}, or an
// annotation-only object such as {"description":"arbitrary JSON"}. An explicit
// union of JSON types preserves its meaning, including null and scalar values.
fn any_json_type() -> Value {
    json!([
        "object", "array", "string", "number", "integer", "boolean", "null"
    ])
}

fn normalize_schema(schema: &mut Value) {
    if *schema == Value::Bool(true) {
        *schema = json!({"type": any_json_type()});
        return;
    }
    if let Value::Object(fields) = schema {
        let composite = ["$ref", "oneOf", "anyOf", "allOf"]
            .iter()
            .any(|keyword| fields.contains_key(*keyword));
        let missing_type = fields
            .get("type")
            .is_none_or(|kind| kind.is_null() || kind.as_array().is_some_and(Vec::is_empty));
        if !composite && missing_type {
            fields.insert("type".into(), any_json_type());
        }
        for keyword in [
            "properties",
            "patternProperties",
            "$defs",
            "definitions",
            "dependentSchemas",
        ] {
            if let Some(Value::Object(children)) = fields.get_mut(keyword) {
                for child in children.values_mut() {
                    normalize_schema(child);
                }
            }
        }
        for keyword in ["oneOf", "anyOf", "allOf", "prefixItems"] {
            if let Some(Value::Array(children)) = fields.get_mut(keyword) {
                for child in children {
                    normalize_schema(child);
                }
            }
        }
        for keyword in [
            "items",
            "contains",
            "not",
            "if",
            "then",
            "else",
            "propertyNames",
        ] {
            if let Some(child) = fields.get_mut(keyword) {
                normalize_schema(child);
            }
        }
        // Boolean additionalProperties is native to utoipa; keep true/false as
        // booleans. Only its schema form needs recursive normalization.
        for keyword in ["additionalProperties", "unevaluatedProperties"] {
            if let Some(child @ Value::Object(_)) = fields.get_mut(keyword) {
                normalize_schema(child);
            }
        }
    }
}

fn normalize_and_check_schema(schema: &mut Value, pointer: &str) -> SchemaResult<()> {
    normalize_schema(schema);
    serde_json::from_value::<utoipa::openapi::RefOr<utoipa::openapi::schema::Schema>>(
        schema.clone(),
    )
    .map_err(|error| schema_error(format!("invalid schema at {pointer}: {error}")))?;
    Ok(())
}

// Run AFTER every registry addition and contract patch, covering component AND
// inline parameter/header/request/response schemas (including pull's body=Value).
// Examples are application payloads, even when they contain a key named schema.
fn normalize_document(value: &mut Value, pointer: &str) -> SchemaResult<()> {
    match value {
        Value::Object(fields) => {
            for (key, child) in fields {
                let location = format!("{pointer}/{}", pointer_segment(key));
                match key.as_str() {
                    "example" | "examples" => (),
                    "schemas" if pointer == "/components" => {
                        let schemas = child.as_object_mut().ok_or_else(|| {
                            schema_error(format!("expected a schema map at {location}"))
                        })?;
                        for (name, schema) in schemas {
                            normalize_and_check_schema(
                                schema,
                                &format!("{location}/{}", pointer_segment(name)),
                            )?;
                        }
                    }
                    "schema" => normalize_and_check_schema(child, &location)?,
                    _ => normalize_document(child, &location)?,
                }
            }
        }
        Value::Array(children) => {
            for (index, child) in children.iter_mut().enumerate() {
                normalize_document(child, &format!("{pointer}/{index}"))?;
            }
        }
        _ => (),
    }
    Ok(())
}

fn add_schema(doc: &mut Value, name: &str, raw: &Value) -> SchemaResult<()> {
    let mut schema = raw.clone();
    let definitions = if let Some(fields) = schema.as_object_mut() {
        fields.remove("$schema");
        fields.remove("$defs")
    } else if schema.is_boolean() {
        None
    } else {
        return Err(schema_error(format!(
            "registry schema {name} must be an object or boolean"
        )));
    };
    rewrite_refs(&mut schema, name);
    insert_component(doc, name, schema)?;
    if let Some(definitions) = definitions {
        let definitions = definitions
            .as_object()
            .ok_or_else(|| schema_error(format!("registry schema {name} has non-object $defs")))?;
        for (key, definition) in definitions {
            let mut definition = definition.clone();
            rewrite_refs(&mut definition, name);
            insert_component(doc, &format!("{name}_{key}"), definition)?;
        }
    }
    Ok(())
}

fn apply_sync_blob_contract(doc: &mut Value) -> SchemaResult<()> {
    typed_schema_at_mut(doc, "/components/schemas/PushOpEnvelope", "object")?;
    let ops = typed_schema_at_mut(
        doc,
        "/components/schemas/PushRequest/properties/ops",
        "array",
    )?;
    if ops
        .get("items")
        .and_then(|items| items.get("$ref"))
        .and_then(Value::as_str)
        != Some(ENVELOPE_REF)
    {
        return Err(schema_error(
            "PushRequest.ops must initially reference PushOpEnvelope",
        ));
    }
    ops.insert("maxItems".into(), json!(50));
    ops.insert(
        "items".into(),
        json!({"$ref": format!("#/components/schemas/{SYNC_OPERATION}")}),
    );
    let spaces = typed_schema_at_mut(
        doc,
        "/components/schemas/PullRequest/properties/spaces",
        "object",
    )?;
    spaces.insert("maxProperties".into(), json!(50));
    let limit = typed_schema_at_mut(
        doc,
        "/components/schemas/PullRequest/properties/limit",
        "integer",
    )?;
    limit.insert("minimum".into(), json!(1));
    limit.insert("maximum".into(), json!(500));
    let path = format!("/paths/{}", pointer_segment(BLOBS_PATH));
    for location in [
        format!("{path}/put/requestBody/content/image~1jpeg/schema"),
        format!("{path}/get/responses/200/content/image~1jpeg/schema"),
    ] {
        let binary = typed_schema_at_mut(doc, &location, "string")?;
        binary.insert("format".into(), json!("binary"));
    }
    Ok(())
}

pub(crate) fn extend(
    document: utoipa::openapi::OpenApi,
    registry: &ToolRegistry,
) -> SchemaResult<utoipa::openapi::OpenApi> {
    serde_json::from_value(extend_value(document, registry)?)
}

fn extend_value(
    document: utoipa::openapi::OpenApi,
    registry: &ToolRegistry,
) -> SchemaResult<Value> {
    let mut doc = serde_json::to_value(document)?;
    object_at_mut(&mut doc, "/components/schemas")?;
    object_at_mut(&mut doc, "/paths")?;
    let mut branches = Vec::new();
    let mut mapping = Map::new();
    let mut sync_branches = Vec::new();
    let mut sync_mapping = Map::new();
    for tool in registry
        .tools()
        .filter(|t| t.exposure() != Exposure::AgentOnly)
    {
        let args = format!("ToolArgs_{}", tool.name());
        let output = format!("ToolResult_{}", tool.name());
        add_schema(&mut doc, &args, tool.parameters())?;
        add_schema(&mut doc, &output, tool.output_schema())?;
        let mut parameters = vec![
            json!({"name":"space_id","in":"path","required":true,"schema":{"type":"string","format":"uuid"}}),
        ];
        if tool.effect() == Effect::LocalWrite {
            parameters.push(json!({"name":"Idempotency-Key","in":"header","required":true,"schema":{"type":"string","minLength":1,"maxLength":200}}));
            parameters.push(json!({"name":"X-Jiabu-Join-Epoch","in":"header","required":false,"description":"Required for session writes; optional for API keys, validated whenever supplied","schema":{"type":"integer","minimum":1}}));
        }
        let mut responses = json!({"200":{"description":"Tool result","content":{"application/json":{"schema":{"$ref":format!("#/components/schemas/{output}")},"example":tool.example_output()}}}});
        for code in [400, 401, 403, 404, 409, 422, 429, 500, 503] {
            responses[code.to_string()] = json!({"description":"Problem","content":{"application/problem+json":{"schema":{"$ref":"#/components/schemas/Problem"}}}});
        }
        responses["429"]["headers"] = json!({"Retry-After":{"description":"Seconds until the next token","schema":{"type":"integer"}}});
        let paths = object_at_mut(&mut doc, "/paths")?;
        let path = tool.api_path();
        if paths.contains_key(&path) {
            return Err(schema_error(format!(
                "generated tool path already exists: {path}"
            )));
        }
        paths.insert(path, json!({"post":{"operationId":format!("tool_{}",tool.name()),"description":tool.description(),"tags":["tools"],"security":[{"bearer":[]}],"parameters":parameters,"requestBody":{"required":true,"content":{"application/json":{"schema":{"$ref":format!("#/components/schemas/{args}")},"example":tool.example_args()}}},"responses":responses}}));
        let branch_name = format!("ToolCall_{}", tool.name());
        insert_component(
            &mut doc,
            &branch_name,
            json!({"type":"object","additionalProperties":false,"required":["tool","args"],"properties":{"tool":{"type":"string","enum":[tool.name()]},"args":{"$ref":format!("#/components/schemas/{args}")}}}),
        )?;
        let reference = format!("#/components/schemas/{branch_name}");
        branches.push(json!({"$ref": reference}));
        mapping.insert(tool.name().into(), json!(reference));

        // Distinct generated names: never overwrite the derive's parsing envelope.
        let branch_name = format!("{SYNC_OPERATION}_{}", tool.name());
        insert_component(
            &mut doc,
            &branch_name,
            json!({"type":"object","additionalProperties":false,
            "required":["op_id","space_id","join_epoch","request_id","tool","args"],"properties":{
                "op_id":{"type":"string","format":"uuid"},"space_id":{"type":"string","format":"uuid"},
                "join_epoch":{"type":"integer","minimum":1},"request_id":{"type":"string","format":"uuid"},
                "tool":{"type":"string","enum":[tool.name()]},"args":{"$ref":format!("#/components/schemas/{args}")}}}),
        )?;
        let reference = format!("#/components/schemas/{branch_name}");
        sync_branches.push(json!({"$ref": reference}));
        sync_mapping.insert(tool.name().into(), json!(reference));
    }
    insert_component(
        &mut doc,
        "ToolCall",
        json!({"oneOf":branches,"discriminator":{"propertyName":"tool","mapping":mapping}}),
    )?;
    insert_component(
        &mut doc,
        SYNC_OPERATION,
        json!({"oneOf":sync_branches,"discriminator":{"propertyName":"tool","mapping":sync_mapping}}),
    )?;
    add_schema(
        &mut doc,
        "DocumentTemplate",
        &serde_json::to_value(jiabu_domain::templates::schema())?,
    )?;
    insert_component(
        &mut doc,
        "TemplatesResponse",
        json!({"type":"object","required":["templates"],"properties":{"templates":{"type":"array","items":{"$ref":"#/components/schemas/DocumentTemplate"}}}}),
    )?;
    if let Some(media) =
        doc.pointer_mut("/paths/~1v1~1templates/get/responses/200/content/application~1json")
    {
        media["schema"] = json!({"$ref":"#/components/schemas/TemplatesResponse"});
    }
    apply_sync_blob_contract(&mut doc)?;
    normalize_document(&mut doc, "")?;
    Ok(doc)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn contract_fixture() -> Value {
        json!({
            "components": {"schemas": {
                "PushOpEnvelope": {"type":"object"},
                "PushRequest": {"type":"object","properties": {
                    "ops": {"type":"array","items":{"$ref":ENVELOPE_REF}}
                }},
                "PullRequest": {"type":"object","properties": {
                    "spaces": {"type":"object","additionalProperties":{"type":"integer"}},
                    "limit": {"type":"integer"}
                }}
            }},
            "paths": {(BLOBS_PATH): {
                "put": {"requestBody":{"content":{"image/jpeg":{"schema":{"type":"string"}}}}},
                "get": {"responses":{"200":{"description":"JPEG","content":{"image/jpeg":{"schema":{"type":"string"}}}}}}
            }}
        })
    }

    #[test]
    fn all_schema_locations_normalize_without_rewriting_examples() -> SchemaResult<()> {
        let example =
            json!({"schema":{},"schemas":{"arbitrary":true},"result":{"description":"payload"}});
        let mut document = contract_fixture();
        let schemas = object_at_mut(&mut document, "/components/schemas")?;
        schemas.insert(
            "Unconstrained".into(),
            json!({"description":"Any JSON, including scalars"}),
        );
        schemas.insert(
            "Values".into(),
            json!({"type":"object","properties":{
                "args":{}, "result":true, "problem":{"description":"Optional problem"},
                "values":{"type":"array","items":{}},
                "map":{"type":"object","additionalProperties":{}},
                "closed":{"type":"object","additionalProperties":false}
            }}),
        );
        let path = format!("/paths/{}", pointer_segment(BLOBS_PATH));
        let request_media = object_at_mut(
            &mut document,
            &format!("{path}/put/requestBody/content/image~1jpeg"),
        )?;
        request_media.insert("schema".into(), json!({"description":"inline request"}));
        request_media.insert("example".into(), example.clone());
        let response_media = object_at_mut(
            &mut document,
            &format!("{path}/get/responses/200/content/image~1jpeg"),
        )?;
        response_media.insert("schema".into(), json!(true));
        response_media.insert("examples".into(), json!({"sample":{"value":example}}));
        normalize_document(&mut document, "")?;
        for pointer in [
            "/components/schemas/Unconstrained/type",
            "/components/schemas/Values/properties/args/type",
            "/components/schemas/Values/properties/result/type",
            "/components/schemas/Values/properties/problem/type",
            "/components/schemas/Values/properties/values/items/type",
            "/components/schemas/Values/properties/map/additionalProperties/type",
        ] {
            assert_eq!(
                document.pointer(pointer),
                Some(&any_json_type()),
                "{pointer}"
            );
        }
        assert_eq!(
            document["components"]["schemas"]["Values"]["properties"]["closed"]["additionalProperties"],
            false
        );
        assert_eq!(
            document["components"]["schemas"]["Unconstrained"]["description"],
            "Any JSON, including scalars"
        );
        for pointer in [
            format!("{path}/put/requestBody/content/image~1jpeg/schema/type"),
            format!("{path}/get/responses/200/content/image~1jpeg/schema/type"),
        ] {
            assert_eq!(document.pointer(&pointer), Some(&any_json_type()));
        }
        assert_eq!(
            document.pointer(&format!(
                "{path}/put/requestBody/content/image~1jpeg/example"
            )),
            Some(&example)
        );
        assert_eq!(
            document.pointer(&format!(
                "{path}/get/responses/200/content/image~1jpeg/examples/sample/value"
            )),
            Some(&example)
        );
        let once = document.clone();
        normalize_document(&mut document, "")?;
        assert_eq!(document, once, "normalization must be idempotent");
        Ok(())
    }

    #[test]
    fn contract_patches_reject_missing_or_unexpected_shapes() -> SchemaResult<()> {
        let blobs = format!("/paths/{}", pointer_segment(BLOBS_PATH));
        let cases = [
            "/components/schemas/PushRequest".to_owned(),
            "/components/schemas/PushRequest/properties/ops".to_owned(),
            "/components/schemas/PullRequest".to_owned(),
            "/components/schemas/PullRequest/properties/limit".to_owned(),
            format!("{blobs}/put/requestBody/content/image~1jpeg/schema"),
            format!("{blobs}/get/responses/200/content/image~1jpeg/schema"),
        ];
        for missing in cases {
            let mut document = contract_fixture();
            let (parent, key) = missing
                .rsplit_once('/')
                .ok_or_else(|| schema_error("invalid fixture pointer"))?;
            let key = key.replace("~1", "/").replace("~0", "~");
            object_at_mut(&mut document, parent)?.remove(&key);
            assert!(
                apply_sync_blob_contract(&mut document).is_err(),
                "{missing}"
            );
            assert!(
                document.pointer(&missing).is_none(),
                "must not synthesize {missing}"
            );
        }
        for (pointer, replacement) in [
            (
                "/components/schemas/PushRequest/properties/ops",
                json!({"$ref":"#/components/schemas/SomeArray"}),
            ),
            (
                "/components/schemas/PushRequest/properties/ops/items",
                json!({"type":"object"}),
            ),
            (
                "/components/schemas/PullRequest/properties/limit",
                json!({"type":"string"}),
            ),
        ] {
            let mut document = contract_fixture();
            *document
                .pointer_mut(pointer)
                .ok_or_else(|| schema_error("missing fixture schema"))? = replacement;
            assert!(
                apply_sync_blob_contract(&mut document).is_err(),
                "{pointer}"
            );
        }
        let mut valid = contract_fixture();
        apply_sync_blob_contract(&mut valid)?;
        assert_eq!(
            valid["components"]["schemas"]["PushRequest"]["properties"]["ops"]["maxItems"],
            50
        );
        assert_eq!(
            valid["components"]["schemas"]["PushRequest"]["properties"]["ops"]["items"]["$ref"],
            format!("#/components/schemas/{SYNC_OPERATION}")
        );
        Ok(())
    }

    #[test]
    fn generated_components_reject_collisions_and_missing_schema_maps() -> SchemaResult<()> {
        let mut document = contract_fixture();
        insert_component(&mut document, SYNC_OPERATION, json!({"oneOf":[]}))?;
        let original = document.clone();
        assert!(insert_component(&mut document, SYNC_OPERATION, json!({"type":"object"})).is_err());
        assert_eq!(document, original);
        let mut missing = json!({"paths":{}});
        assert!(insert_component(&mut missing, "SomeSchema", json!({"type":"object"})).is_err());
        assert!(missing.get("components").is_none());
        Ok(())
    }
}
