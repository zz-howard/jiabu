# SIWC live captures

Captured 2026-10-29 from the ChatGPT subscription backend (`https://api.openai.com/v1/responses`),
model `gpt-6.1-sol`, through `SiwcProvider` with a local capture patch (not in the repository).
Each case pairs the request body exactly as serialized by `request::body` with the raw SSE bytes as
received. Replay tests: `crates/ai/tests/siwc.rs` (parser) and `crates/eval/tests/siwc_replay.rs`
(parser, then the Agent loop, tool validation and PG).

| Case | Files | Covers |
|---|---|---|
| Plain text | `text.request.json`, `text.response.sse` | No tools; `output_text` deltas, `message` item with `phase`, `response.metadata`, usage. |
| Tool call | `tool_call.request.json`, `tool_call.response.sse` | The current wire shape: the Agent prompt of eval entry `zh-single-001` with all 28 tools in the `jiabu` namespace, of which 9 are sent `strict: true` (the strict-compatible ones) and 19 `strict: false`. The model calls `ask_user`. The call arrives as a bare `name` plus `"namespace": "jiabu"`. |
| Follow-up | `follow_up.request.json`, `follow_up.response.sse` | Second turn after `function_call` + `function_call_output`; text answer. |
| Rejection | `rejection.request.json`, `rejection.event.json` | The request that failed in production: every tool marked `strict: true`, and `ask_user` leaves optional `fields`/`options` out of `required`. Upstream answers with an `error` event, `invalid_function_parameters` (`invalid_request_error`). |

Caveats:
- The follow-up was captured earlier, with an interim strict view of all 28 tools (optional fields
  rewritten as required-but-nullable). That variant was dropped, so its request is a real accepted
  exchange but not the current tool shape; `request::body` still rebuilds it (JSON-equal) from its
  own schemas. Its tool result is the synthetic `create_record` example output paired with that
  capture's `ask_user` call id. It exercises continuation and parsing, not tool semantics.
- The rejection case was recorded as parsed JSON (re-serialized), not raw bytes.
- No reasoning items occurred, so `encrypted_content` / provider blobs are not covered.

Sanitization: HTTP headers (authorization, session, account) were never recorded. Upstream ids
(`resp_`, `msg_`, `fc_`, `call_`) are replaced by synthetic ids of the same prefix and length,
consistently across files. `safety_identifier` is replaced by `user-synthetic`, and the
prompt-cache key is synthetic. Everything else is byte-faithful, including moderation metadata and
the `obfuscation` padding. The prompt context is fictional eval data. Before commit, a mechanical
scan checked for the credential's tokens, the account and subject ids, the OAuth client and host
ids, email addresses, bearer/JWT/`sk-` patterns, auth header names and the original upstream ids:
no hits.
