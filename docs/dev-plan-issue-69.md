# Dev Plan: Local-First Cold Start (#69)

## Summary

Cold start currently awaits the online `me()` identity check inside `LocalAuthRepository._resume()` before the session (and therefore the sync/ledger/chat runtime) is activated. All data is local, so the app should open immediately from the persisted identity and verify the identity in the background. The chat page also shows the ledger string "记录同步中" while its local session opens; it gets its own neutral loading text.

## Scope

In scope:

- `_resume()`: when the partition's runtime row is authenticated, has a persisted `identity_json` and a `full` session kind, build the session from that identity immediately (same construction as today's network-error fallback, honoring `activateOnResume`), publish it, then verify `me()` in the background.
- Background verification, guarded by the session object and its runtime generation:
  - success, same user: refresh the saved identity; keep the session (replace `current` only if the user data changed, without tearing down the runtime);
  - user id mismatch: invalidate the session (same end state as today's `session_user_mismatch`: the user is not left signed in);
  - 401: existing invalidate / authentication-lost path;
  - `password_change_required`: switch to the restricted password-change session, as the blocking path does today;
  - network, 426 and other errors: keep the local session (offline-capable; 426 still reaches the transport's client-too-old handling).
- No persisted authenticated identity (first resume after a partial login, restricted sessions): keep the current blocking behavior.
- Chat page: new ARB key `chatOpening` (zh "正在打开聊天", en "Opening chat") instead of `ledgerLoading`.

Out of scope: auth redesign, server changes, sync engine changes.

## Dev checklist

- [ ] Extract the persisted-identity session construction into a helper shared by the fast path and the network fallback.
- [ ] Extract the restricted-session activation into a helper shared by blocking and background paths.
- [ ] Add the fast path and `_verifyIdentity` with generation/`identical(current, session)` guards; expose `verificationWork` (like `logoutWork`) for tests.
- [ ] Start the background request after `onChanged`, so the runtime's transport revision/generation guards apply to it.
- [ ] Add `chatOpening` to both ARB files; use it in `chat_screen.dart`.

## Test checklist

- [ ] Cold start resolves with a session while `me()` never completes.
- [ ] Background 401 clears the token and signs out, data kept.
- [ ] Background user mismatch signs out.
- [ ] Late background result after a newer session (generation changed) is ignored.
- [ ] No persisted identity: resume still waits for `me()`.
- [ ] Background success refreshes the saved identity without a new session.
- [ ] Chat page shows "正在打开聊天" while the conversation opens.
- [ ] Update tests asserting the old blocking order (401 now arrives after resume returns).
- [ ] Full client CI sequence on the build host.

## Assumptions

- "Persisted authenticated identity" = runtime row `authenticated = 1`, `session_kind = 'full'`, non-null `identity_json`. Restricted sessions are already `authenticated = 0` and keep the blocking path.
- A background mismatch invalidates the session (deletes the token) rather than only failing resume; a token that belongs to another user is not reusable.
- The background check is not awaited by `AppRuntime.close()`, so a dead network cannot delay shutdown; late results are discarded by the guards.

## Acceptance

- Cold start shows local ledger/chat data without a network round trip when a persisted identity exists.
- Background verification failures end in the same states as today's blocking checks; stale results never affect a newer session.
- Client CI sequence green.
