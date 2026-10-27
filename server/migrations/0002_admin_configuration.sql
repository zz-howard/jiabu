-- S1: append migrations after release; never edit an applied migration.

create table admin_tokens (id uuid primary key default uuidv7(), name text not null,
  token_hash bytea unique not null, display_prefix text not null,
  scope text not null check (scope in ('read','write')),
  expires_at timestamptz, created_at timestamptz not null default now(), created_by text not null,
  last_used_at timestamptz, revoked_at timestamptz);

create table admin_audit (id bigint generated always as identity primary key,
  at timestamptz not null default now(),
  actor_kind text not null check (actor_kind in ('cli','token')),
  actor_token_id uuid references admin_tokens, actor_label text,
  action text not null,
  target_kind text, target_id text, request_id uuid,
  detail jsonb);

create table ai_providers (id text primary key,
  kind text not null, base_url text,
  billing text not null check (billing in ('subscription','local','paid')),
  secret_source text,
  enabled boolean not null default true, version int not null default 1,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now());

create table ai_models (id uuid primary key default uuidv7(), provider_id text not null references ai_providers,
  model text not null, structured text not null, vision boolean not null, context_tokens int,
  enabled boolean not null default true, unique (provider_id, model));

create table ai_routes (task_kind text not null check (task_kind in ('chat','chat_vision','probe')), position smallint not null,
  model_id uuid not null references ai_models, primary key (task_kind, position));

create table ai_settings (id boolean primary key default true check (id),
  allow_paid_fallback boolean not null default false, breaker jsonb not null, config_version bigint not null default 1);

create table ai_prices (id uuid primary key default uuidv7(),
  provider_kind text not null, model text not null,
  currency text not null default 'USD',
  input numeric(12,6) not null, cached_input numeric(12,6), output numeric(12,6) not null,
  cache_write jsonb,
  long_context jsonb,
  source text not null, as_of date not null, effective_from timestamptz not null,
  created_at timestamptz not null default now());

create table secrets (id uuid primary key default uuidv7(), owner_kind text not null, owner_id text not null,
  field text not null, key_id text not null, nonce bytea not null, ciphertext bytea not null,
  last4 text not null, updated_at timestamptz not null default now(), unique (owner_kind, owner_id, field));

create table app_releases (
  build int primary key,
  version text not null,
  channel text not null check (channel in ('stable','beta')),
  abi text not null default 'arm64-v8a',
  sha256 bytea not null, bytes bigint not null,
  cert_sha256 bytea not null,
  min_server_api int not null,
  security_force boolean not null default false,
  notes jsonb not null,
  source text not null check (source in ('github','manual')),
  status text not null check (status in ('available','rejected','withdrawn')),
  reject_reason text,
  published_at timestamptz, fetched_at timestamptz not null default now());
