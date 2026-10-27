-- S1: append migrations after release; never edit an applied migration.
create sequence change_seq;

create table users (
  id uuid primary key default uuidv7(),
  username text not null,
  password_hash text not null,
  locale text not null default 'system' check (locale in ('system','zh-Hans','en')),
  must_change_password boolean not null default false,
  admin_reset_at timestamptz,
  admin_reset_notice_pending boolean not null default false,
  disabled_at timestamptz,
  password_changed_at timestamptz,
  created_at timestamptz not null default now());
create unique index users_username on users (lower(username));

create table sessions (
  id uuid primary key default uuidv7(),
  token_hash bytea not null unique,
  user_id uuid not null references users,
  kind text not null check (kind in ('full','password_change')),
  device_name text,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  last_seen_at timestamptz not null default now());
create index sessions_user on sessions (user_id);

create table api_keys (id uuid primary key default uuidv7(), user_id uuid not null references users,
  name text not null, token_hash bytea unique not null,
  display_prefix text not null,
  scope text not null check (scope in ('read','read_write')),
  expires_at timestamptz,
  created_at timestamptz not null default now(), last_used_at timestamptz,
  revoked_at timestamptz, revoked_by text check (revoked_by in ('user','admin')));

create table idempotency (
  user_id uuid not null references users,
  key text not null,
  request_hash bytea not null,
  response_status smallint, response_body jsonb,
  created_at timestamptz not null default now(),
  primary key (user_id, key));
create index idempotency_created on idempotency (created_at);

create table spaces (
  id uuid primary key,
  name text not null check (char_length(name) between 1 and 40),
  accent_color text not null,
  currency char(3) not null default 'CNY',
  timezone text not null,
  is_default boolean not null default false,
  created_by_user_id uuid not null references users,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  version int not null default 1, change_seq bigint not null);
create unique index one_default_space_per_user on spaces (created_by_user_id) where is_default;

create table space_members (
  id uuid primary key default uuidv7(),
  space_id uuid not null references spaces,
  user_id uuid not null references users,
  display_name text not null check (char_length(display_name) between 1 and 20),
  role text not null check (role in ('owner','member')),
  status text not null check (status in ('active','left')),
  left_reason text check (left_reason in ('left','removed','space_deleted')),
  join_epoch int not null default 1,
  joined_at timestamptz not null, left_at timestamptz,
  version int not null default 1, change_seq bigint not null,
  unique (space_id, user_id));
create index space_members_user on space_members (user_id) where status = 'active';

create table space_member_grants (member_id uuid not null references space_members,
  module text not null,
  level text not null check (level in ('none','read','write','manage')),
  change_seq bigint not null, primary key (member_id, module));

create table space_invitations (
  id uuid primary key default uuidv7(),
  space_id uuid not null references spaces,
  invitee_user_id uuid not null references users,
  invited_by_member_id uuid not null references space_members,
  status text not null check (status in ('pending','accepted','declined','cancelled')),
  created_at timestamptz not null default now(), decided_at timestamptz);
create unique index one_pending_invitation on space_invitations (space_id, invitee_user_id) where status = 'pending';
create index space_invitations_invitee on space_invitations (invitee_user_id) where status = 'pending';

create table space_events (id bigint generated always as identity primary key, space_id uuid not null,
  actor_member_id uuid references space_members, subject_member_id uuid references space_members,
  request_id uuid, kind text not null,
  at timestamptz not null default now());

create index sessions_expiry on sessions (expires_at);
create index spaces_sync on spaces (id, change_seq);
create index space_members_sync on space_members (space_id, change_seq);
create index space_member_grants_sync on space_member_grants (member_id, change_seq);

create table api_key_audit (id bigint generated always as identity primary key,
  at timestamptz not null default now(), api_key_id uuid not null references api_keys,
  user_id uuid not null, space_id uuid,
  operation text not null,
  effect text not null check (effect in ('read','local_write')),
  outcome text not null,
  request_id uuid, idempotency_key text);
create index api_key_audit_at on api_key_audit (at);
