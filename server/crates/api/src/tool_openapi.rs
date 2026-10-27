//! Registry schemas are also the public API schemas. No second DTO definitions.
use jiabu_tools::{Effect, Exposure, ToolRegistry};
use serde_json::{Value, json};

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
// schemars emits the boolean schema `true` (or `{}`) for serde_json::Value.
// utoipa cannot read either back, so spell out "any JSON value" by type.
fn normalize_schema(schema: &mut Value) {
    if *schema == Value::Bool(true) || *schema == json!({}) {
        *schema = json!({"type":["object","array","string","number","integer","boolean","null"]});
        return;
    }
    if let Value::Object(fields) = schema {
        for keyword in ["properties", "patternProperties", "$defs"] {
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
        for keyword in ["items", "contains", "not", "if", "then", "else"] {
            if let Some(child) = fields.get_mut(keyword) {
                normalize_schema(child);
            }
        }
    }
}
fn add_schema(components: &mut Value, name: &str, raw: &Value) {
    let mut schema = raw.clone();
    normalize_schema(&mut schema);
    let definitions = schema.as_object_mut().and_then(|o| o.remove("$defs"));
    if let Some(object) = schema.as_object_mut() {
        object.remove("$schema");
    }
    rewrite_refs(&mut schema, name);
    components[name] = schema;
    if let Some(Value::Object(definitions)) = definitions {
        for (key, mut definition) in definitions {
            rewrite_refs(&mut definition, name);
            components[format!("{name}_{key}")] = definition;
        }
    }
}
pub(crate) fn extend(
    document: utoipa::openapi::OpenApi,
    registry: &ToolRegistry,
) -> Result<utoipa::openapi::OpenApi, serde_json::Error> {
    serde_json::from_value(extend_value(document, registry)?)
}
fn extend_value(
    document: utoipa::openapi::OpenApi,
    registry: &ToolRegistry,
) -> Result<Value, serde_json::Error> {
    let mut doc = serde_json::to_value(document)?;
    if doc["components"].is_null() {
        doc["components"] = json!({});
    }
    if doc["components"]["schemas"].is_null() {
        doc["components"]["schemas"] = json!({});
    }
    // utoipa writes serde_json::Value fields as `{}` but cannot read them back;
    // normalize the handwritten components too before the round trip.
    if let Some(Value::Object(schemas)) = doc["components"].get_mut("schemas") {
        for schema in schemas.values_mut() {
            normalize_schema(schema);
        }
    }
    let mut branches = Vec::new();
    let mut mapping = serde_json::Map::new();
    for tool in registry
        .tools()
        .filter(|t| t.exposure() != Exposure::AgentOnly)
    {
        let args = format!("ToolArgs_{}", tool.name());
        let output = format!("ToolResult_{}", tool.name());
        add_schema(&mut doc["components"]["schemas"], &args, tool.parameters());
        add_schema(
            &mut doc["components"]["schemas"],
            &output,
            tool.output_schema(),
        );
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
        doc["paths"][tool.api_path()] = json!({"post":{"operationId":format!("tool_{}",tool.name()),"description":tool.description(),"tags":["tools"],"security":[{"bearer":[]}],"parameters":parameters,"requestBody":{"required":true,"content":{"application/json":{"schema":{"$ref":format!("#/components/schemas/{args}")},"example":tool.example_args()}}},"responses":responses}});
        let branch_name = format!("ToolCall_{}", tool.name());
        doc["components"]["schemas"][&branch_name] = json!({"type":"object","additionalProperties":false,"required":["tool","args"],"properties":{"tool":{"type":"string","enum":[tool.name()]},"args":{"$ref":format!("#/components/schemas/{args}")}}});
        let reference = format!("#/components/schemas/{branch_name}");
        branches.push(json!({"$ref":reference}));
        mapping.insert(tool.name().into(), json!(reference));
    }
    doc["components"]["schemas"]["ToolCall"] =
        json!({"oneOf":branches,"discriminator":{"propertyName":"tool","mapping":mapping}});
    Ok(doc)
}
