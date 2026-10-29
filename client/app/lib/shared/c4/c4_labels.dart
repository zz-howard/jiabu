import 'package:jiabu/l10n/generated/app_localizations.dart';

String c4Error(AppLocalizations l, String code) => switch (code) {
  'offline' || 'network' => l.c4Offline,
  'not_found' => l.c4NotFound,
  'invitation_expired' => l.c4InvitationExpired,
  'space_last_owner' => l.c4LastOwner,
  'space_not_empty' => l.c4SpaceNotEmpty,
  'space_name_mismatch' => l.c4NameMismatch,
  'default_space_forbidden' => l.c4DefaultForbidden,
  'version_conflict' || 'membership_changed' => l.c4VersionConflict,
  'api_key_limit_reached' => l.c4KeyLimit,
  'validation_failed' => l.c4Validation,
  'rate_limited' => l.c4RateLimited,
  'unauthenticated' || 'account_disabled' => l.c4SessionExpired,
  'mismatch' => l.c4Mismatch,
  'lock_wait' => l.c4LockWait,
  'lock_failed' => l.c4LockError,
  'plaintext_unavailable' => l.c4KeyReplay,
  _ => l.c4Error,
};

String invitationStatus(AppLocalizations l, String status) => switch (status) {
  'accepted' => l.c4Accepted,
  'declined' => l.c4Declined,
  'cancelled' => l.c4Cancelled,
  _ => l.c4Pending,
};
