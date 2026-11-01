# Dev Plan: Attach PDF files to chat messages (#68)

## Summary

Let a member attach PDF files to a chat message from the Flutter client, using
the generic space file endpoint and the chat `files` input that the server
already supports (#47 / PR #48). Files follow the same durable path as chat
images: stored locally, uploaded through the outbox before the message is
sent, and retried offline.

## Scope

In scope:

- Attachment sheet 「文件」 tab picks PDFs through the Android Storage Access
  Framework (`ACTION_OPEN_DOCUMENT`, `application/pdf`, multi-select, no
  storage permission). The native channel returns bytes, display name and
  size per document; the photo tabs are unchanged. Platforms without the
  channel get a clear "not supported" failure.
- Local validation mirroring the server: `%PDF-d.d` header and `%%EOF` in the
  last 1 KiB followed only by whitespace/NUL; at most 10 MiB per file, 4 files
  per message, 20 MiB combined (counting files already attached); display
  name sanitized to the server's rules.
- Import: hash the raw bytes, write `<blobs>/<sha256>.pdf`, `putBlob` module
  `chat_file`, and enqueue outbox kind `blob` (`module: chat_file`) in the same
  transaction. No drift migration (module is free text, kind reuses `blob`).
- Outbox upload branch for `chat_file`: `PUT v1/spaces/{space}/files/{sha256}`
  with `application/pdf`, join epoch, Idempotency-Key and X-Request-Id. 204 is
  success; 413/415/422 permanent; 503 retried with Retry-After.
- Draft persistence of attached files; `chat_send` payload carries
  `files: [{sha256, name}]` and waits on `blob:chat_file:<hash>`; optimistic
  `metadata.input.files` carries mime/bytes for display; `retryUpload` also
  resets failed file uploads. Images and files can coexist.
- UI: removable file chips (name + size) above the composer; non-interactive
  file chips in sent user notes (optimistic and server-synced); new Files-tab
  note copy; localized errors (too large / too many / not a PDF / picker
  unsupported). Existing run error display covers "no file-capable model".
- Orphan cleanup in BlobCacheService also covers `.pdf`.

Out of scope: non-PDF formats, preview/thumbnails, opening or downloading files
from history, server changes.

## Dev checklist

- [ ] Domain: `ChatFile` value + limits, PDF signature check, name sanitizer.
- [ ] Native picker method `pickPdfs` in MainActivity (bytes, name, size,
      bounded reads); Dart `DocumentPickerPort` + platform implementation.
- [ ] MediaService: `pickFiles` (validation) + `importFile` (one transaction).
- [ ] ApiClient/DioApiClient `uploadFile`; outbox processor module branch.
- [ ] ChatConversation/LocalChatSession: `draftFiles`, `saveDraft` with files,
      `send` with files, `files()` picker entry, retryUpload unchanged path.
- [ ] ChatViewModel/ChatUiState: `files`, `attachFiles`, `removeFile`.
- [ ] UI: chips widget, composer send enablement, user note chips, sheet note,
      error labels, ARB zh/en.
- [ ] BlobCacheService `.pdf` orphan cleanup.
- [ ] Catalog states for goldens (`user_files`, `composer_files`).

## Test checklist

- [ ] Unit: PDF check (header/trailer variants), name sanitizer (separators,
      control chars, dots, empty, 255-byte UTF-8 boundary).
- [ ] Media: import writes `<hash>.pdf`, blob row and outbox op atomically;
      limits (count, per-file, combined), not-PDF, unsupported picker.
- [ ] Outbox: upload branch success, 413/415 permanent, 503 retry.
- [ ] Session: send payload/metadata/dependsOn, draft persistence, retryUpload.
- [ ] Widgets: composer chips + removal, sent-message chips, Files tab copy,
      native channel arguments/decoding.
- [ ] API contract: `uploadFile` request shape.
- [ ] Goldens for the new/changed catalog states (build host only).
- [ ] Release APK build (Kotlin compiles).

## Assumptions

- The Files tab becomes PDF-only; image files remain reachable through the
  photo picker (gallery). The native image channel method stays for reuse.
- When a pick exceeds a limit the whole selection is rejected with an error,
  rather than silently truncated.
- Retention expiry of uploaded originals also applies to PDFs; acceptable
  because there is no open/download UI in this slice.

## Acceptance

- A PDF picked from the Files tab shows as a removable chip, survives app
  restart as part of the draft, uploads before the message, and the sent note
  shows the file chip; the server receives `files: [{sha256, name}]`.
- Oversized / too many / non-PDF selections show clear localized errors and
  attach nothing.
- Offline send queues; failed uploads are retryable from the note.
- Full client CI sequence green on the build host; release APK builds.
