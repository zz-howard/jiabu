# Jiabu Flutter client — rules for coding agents

Fake data only. Never print or commit secrets. Build, test, and generate goldens
only on the x86_64 Linux build host.

Commands: `flutter pub get`, `dart format --set-exit-if-changed .`,
`flutter analyze --fatal-infos`, `dart run tool/check_rules.dart`.
Run `flutter test` separately at workspace root, app, and packages/jiabu_design.
Use `tool/golden.sh` for goldens. Keep Flutter fixed by `.fvmrc`.
Run code generation and parity reporting when those tools are introduced.

- View → generated Riverpod Notifier/AsyncNotifier ViewModel → Repository → Service.
  Views never import data/. Repositories return Result; immutable UiState uses freezed.
- drift is the source of truth. Local writes and outbox changes share ONE transaction.
  Tables, queries, and repositories explicitly carry spaceId. Never show, count,
  or hint at another space's data. Login storage is scoped by server and account.
- Mutating requests carry Idempotency-Key (outbox.id) and X-Request-Id. Space writes
  also carry X-Jiabu-Join-Epoch. Money is integer minor units, never double.
- Colors, fonts, and motion come from jiabu_design tokens. No UI literals in
  features/data. Keep cards, lists, forms, and sheets at zero rotation; decorate
  only through Tilt and deterministic tiltFor. Use JiabuIcons for business UI.
- Hand fonts are for ARB keys starting with hand; user text uses system sans.
  Visible strings use gen-l10n ARB. B0 intentionally has no visible strings.
- ChatWeave BlockRegistry renders replies. Never derive components from model
  text; custom x-jiabu.* blocks carry references. Add ChatWeave only after CW2.
- Use JiabuMotion and honor disableAnimations. Do not override scroll physics.
- Add unit tests for ViewModel/repository changes, interaction widget tests, goldens
  for visual states, and geometry checks for decorations. Later UI slices cover
  two accents, 390/360 widths, and 100%/200% text. B0 has one blank-page baseline.
- Update goldens only for an authorized visual change, inside the fixed image.
  Review PNG files, attach comparisons, and label the PR visual-change.
- Forbidden: Riverpod legacy APIs, setState for business data, unexplained nullable
  assertions, unapproved dependencies, http, google_fonts, firebase packages,
  sqlite3_flutter_libs, isar, and GetX. Review tool/allowed_deps.yaml changes manually.
