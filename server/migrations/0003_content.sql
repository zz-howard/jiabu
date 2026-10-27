-- S1: append migrations after release; never edit an applied migration.

create table accounts (
  id uuid primary key, space_id uuid not null references spaces,
  module text not null default 'ledger' check (module = 'ledger'), visibility jsonb,
  kind text not null check (kind in ('real','purpose')),
  name text not null check (char_length(name) between 1 and 30),
  is_reserve boolean not null default false,
  opening_balance_minor bigint not null default 0,
  opening_on date not null,
  sort_key int not null default 0,
  created_by_member_id uuid not null references space_members,
  archived_at timestamptz,
  version int not null default 1, change_seq bigint not null,
  created_at timestamptz not null, updated_at timestamptz not null,
  check (not is_reserve or kind = 'purpose'));
create unique index accounts_one_reserve on accounts (space_id) where is_reserve and archived_at is null;
create unique index accounts_name on accounts (space_id, kind, lower(name)) where archived_at is null;
create index accounts_sync on accounts (space_id, change_seq);

create table allocation_plans (
  account_id uuid primary key references accounts,
  space_id uuid not null references spaces,
  amount_minor bigint not null check (amount_minor > 0),
  day_of_month smallint not null check (day_of_month between 1 and 31),
  enabled boolean not null default true,
  next_run_on date not null,
  last_run_month char(7),
  version int not null default 1, change_seq bigint not null, updated_at timestamptz not null);
create index allocation_plans_due on allocation_plans (next_run_on) where enabled;
create index allocation_plans_sync on allocation_plans (space_id, change_seq);

create table tags (
  id uuid primary key, space_id uuid not null references spaces,
  module text not null default 'ledger' check (module = 'ledger'),
  preset_key text,
  name text,
  created_by_member_id uuid references space_members,
  deleted_at timestamptz,
  version int not null default 1, change_seq bigint not null,
  check (preset_key is not null or name is not null));
create unique index tags_preset on tags (space_id, preset_key) where preset_key is not null;
create index tags_sync on tags (space_id, change_seq);

create table records (
  id uuid primary key, space_id uuid not null references spaces,
  module text not null default 'ledger' check (module = 'ledger'), visibility jsonb,
  kind text not null check (kind in ('expense','income','transfer','allocation','reallocation','refund')),
  amount_minor bigint not null check (amount_minor > 0),
  occurred_on date not null,
  account_id uuid references accounts,
  to_account_id uuid references accounts,
  purpose_id uuid references accounts,
  to_purpose_id uuid references accounts,
  refund_of_id uuid references records,
  tag_ids uuid[] not null default '{}',
  note text check (char_length(note) <= 500),
  attachments text[] not null default '{}',
  status text not null default 'active' check (status in ('active','voided')),
  void_reason text check (void_reason in ('user')),
  origin text not null check (origin in ('chat','manual','api','allocation')),
  run_id uuid,
  created_by_member_id uuid references space_members,
  updated_by_member_id uuid references space_members,
  version int not null default 1, change_seq bigint not null,
  created_at timestamptz not null, updated_at timestamptz not null,
  constraint records_shape check (
    (kind = 'expense'      and account_id is not null and purpose_id is not null and to_account_id is null and to_purpose_id is null and refund_of_id is null) or
    (kind = 'income'       and account_id is not null and purpose_id is null     and to_account_id is null and to_purpose_id is null and refund_of_id is null) or
    (kind = 'transfer'     and account_id is not null and to_account_id is not null and purpose_id is null and to_purpose_id is null and refund_of_id is null) or
    (kind = 'allocation'   and purpose_id is not null and account_id is null     and to_account_id is null and to_purpose_id is null and refund_of_id is null) or
    (kind = 'reallocation' and purpose_id is not null and to_purpose_id is not null and account_id is null and to_account_id is null and refund_of_id is null) or
    (kind = 'refund'       and account_id is not null and purpose_id is not null and refund_of_id is not null and to_account_id is null and to_purpose_id is null)));
create index records_sync on records (space_id, change_seq);
create index records_date on records (space_id, occurred_on);
create index records_account on records (account_id) where status = 'active';
create index records_to_account on records (to_account_id) where status = 'active';
create index records_purpose on records (purpose_id) where status = 'active';
create index records_to_purpose on records (to_purpose_id) where status = 'active';
create index records_refund_of on records (refund_of_id) where status = 'active';
create index records_tags on records using gin (tag_ids);

create table subjects (
  id uuid primary key, space_id uuid not null references spaces,
  module text not null default 'documents' check (module = 'documents'), visibility jsonb,
  kind text not null check (kind in ('family_member','pet','property','vehicle','other')),
  name text not null check (char_length(name) between 1 and 30),
  member_id uuid references space_members,
  archived_at timestamptz,
  deleted_at timestamptz,
  created_by_member_id uuid not null references space_members,
  version int not null default 1, change_seq bigint not null,
  created_at timestamptz not null, updated_at timestamptz not null);
create unique index subjects_name on subjects (space_id, kind, lower(name)) where deleted_at is null;
create index subjects_sync on subjects (space_id, change_seq);

create table documents (
  id uuid primary key, space_id uuid not null references spaces,
  module text not null default 'documents' check (module = 'documents'), visibility jsonb,
  template_id text,
  template_version int,
  title text not null check (char_length(title) between 1 and 60),
  event_date date not null,
  subject_ids uuid[] not null default '{}',
  content jsonb not null,
  status text not null default 'active' check (status in ('active','voided')),
  origin text not null check (origin in ('chat','manual','api')),
  run_id uuid,
  created_by_member_id uuid not null references space_members,
  updated_by_member_id uuid not null references space_members,
  version int not null default 1, change_seq bigint not null,
  created_at timestamptz not null, updated_at timestamptz not null);
create index documents_sync on documents (space_id, change_seq);
create index documents_timeline on documents (space_id, event_date desc) where status = 'active';
create index documents_template on documents (space_id, template_id, event_date) where status = 'active';
create index documents_subjects on documents using gin (subject_ids);

create table template_snapshots (id text primary key, version int not null, body jsonb not null,
  loaded_at timestamptz not null default now());

create table blobs (sha256 bytea primary key, mime text not null check (mime = 'image/jpeg'), bytes bigint not null,
  width int, height int, created_at timestamptz not null default now());

create table blob_refs (
  id uuid primary key default uuidv7(),
  space_id uuid not null references spaces,
  module text not null check (module in ('ledger','documents','chat')),
  sha256 bytea not null references blobs,
  uploaded_by_member_id uuid not null references space_members,
  created_at timestamptz not null default now());
create unique index blob_refs_chat on blob_refs (space_id, sha256, uploaded_by_member_id) where module = 'chat';
create unique index blob_refs_module on blob_refs (space_id, module, sha256) where module <> 'chat';

create table entity_events (
  id bigint generated always as identity primary key,
  space_id uuid not null references spaces,
  entity_kind text not null check (entity_kind in ('record','account','allocation_plan','tag','document','subject')),
  entity_id uuid not null,
  kind text not null check (kind in ('create','update','void','restore','archive','unarchive','delete')),
  before jsonb, after jsonb,
  actor_member_id uuid references space_members,
  via_api_key_id uuid references api_keys, via_api_key_name text,
  run_id uuid, request_id uuid,
  at timestamptz not null default now(),
  change_seq bigint not null);
create index entity_events_entity on entity_events (entity_id, id);
create index entity_events_sync on entity_events (space_id, change_seq);
