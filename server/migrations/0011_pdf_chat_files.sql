-- Generic chat files: PDF is the only accepted v1 media type.

alter table blobs drop constraint blobs_mime_check;
alter table blobs add constraint blobs_mime_check
  check (mime in ('image/jpeg','application/pdf'));
alter table blobs add constraint blobs_dimensions_check check (
  (mime='image/jpeg' and width is not null and height is not null) or
  (mime='application/pdf' and width is null and height is null));

alter table blob_refs drop constraint blob_refs_module_check;
alter table blob_refs add constraint blob_refs_module_check
  check (module in ('ledger','documents','chat','chat_file'));
drop index blob_refs_chat;
drop index blob_refs_module;
create unique index blob_refs_chat on blob_refs (space_id,sha256,uploaded_by_member_id)
  where module in ('chat','chat_file');
create unique index blob_refs_module on blob_refs (space_id,module,sha256)
  where module not in ('chat','chat_file');

alter table ai_routes drop constraint ai_routes_task_kind_check;
alter table ai_routes add constraint ai_routes_task_kind_check
  check (task_kind in ('chat','chat_vision','chat_file','probe'));
alter table ai_calls drop constraint ai_calls_task_kind_check;
alter table ai_calls add constraint ai_calls_task_kind_check
  check (task_kind in ('chat','chat_vision','chat_file','probe'));
