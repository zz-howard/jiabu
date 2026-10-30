import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jiabu/app/c4_providers.dart';
import 'package:jiabu/app/ledger_providers.dart';
import 'package:jiabu/app/providers.dart';
import 'package:jiabu/app/runtime.dart';
import 'package:jiabu/data/api/dto/auth_dto.dart';
import 'package:jiabu/data/db/database_manager.dart';
import 'package:jiabu/data/repositories/auth_repository.dart';
import 'package:jiabu/data/services/app_settings_service.dart';
import 'package:jiabu/data/services/biometric_auth_service.dart';
import 'package:jiabu/data/services/device_context_service.dart';
import 'package:jiabu/data/services/session_store_service.dart';
import 'package:jiabu/data/services/window_privacy_service.dart';
import 'package:jiabu/domain/api_keys.dart';
import 'package:jiabu/domain/app_lock.dart';
import 'package:jiabu/domain/partition.dart';
import 'package:jiabu/domain/required_value.dart';
import 'package:jiabu/domain/result.dart';
import 'package:jiabu/domain/spaces.dart';
import 'package:jiabu/features/lock/view/lock_settings_screen.dart';
import 'package:jiabu/features/lock/view/unlock_screen.dart';
import 'package:jiabu/features/settings/api_keys/api_keys_screen.dart';
import 'package:jiabu/features/settings/view/settings_screen.dart';
import 'package:jiabu/features/spaces/view/spaces_screen.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu/shared/c4/c4_confirmation.dart';
import 'package:jiabu/shared/c4/c4_ui_state.dart';
import 'package:jiabu/shared/c4/c4_view_model.dart';

/// Synthetic, deterministic fixtures shared with layout/golden/interaction
/// tests. No network, database opening or platform credential access occurs.
const c4States = <String>[
  'switcher',
  'switcher_offline',
  'space_new',
  'space_edit',
  'space_validation',
  'space_personal',
  'space_owner',
  'space_member',
  'space_offline',
  'members',
  'members_left',
  'invite',
  'sent_invitations',
  'received',
  'received_empty',
  'received_offline',
  'invitation_expired',
  'leave',
  'leave_pending',
  'leave_last_owner',
  'remove',
  'transfer',
  'delete_unmatched',
  'delete_matched',
  'settings',
  'account',
  'password',
  'password_error',
  'language',
  'about',
  'lock_disabled',
  'lock_enabled',
  'lock_pattern_setup',
  'lock_pin_mismatch',
  'unlock_biometric',
  'unlock_pin',
  'unlock_pattern',
  'unlock_error',
  'unlock_wait',
  'unlock_recovery',
  'keys_empty',
  'keys_list',
  'keys_offline',
  'keys_failure',
  'key_create',
  'key_never',
  'key_once',
  'key_copied',
  'key_replay',
  'key_details',
  'key_revoke',
  'key_saved_confirm',
  'logout_confirm',
  'keys_inactive',
];

const c4EnglishStates = <String>[
  'switcher',
  'space_new',
  'space_owner',
  'members',
  'invite',
  'sent_invitations',
  'received',
  'leave_pending',
  'remove',
  'transfer',
  'delete_matched',
  'settings',
  'account',
  'password',
  'language',
  'about',
  'lock_disabled',
  'lock_pattern_setup',
  'unlock_pin',
  'keys_list',
  'key_create',
  'key_once',
  'key_details',
  'key_revoke',
  'key_saved_confirm',
  'logout_confirm',
];

SpaceInfo c4Space({
  String role = 'owner',
  bool personal = false,
  bool left = false,
  bool single = false,
  String accent = 'pine',
}) => SpaceInfo(
  id: 'space-a',
  name: '用户A的空间',
  accent: accent,
  currency: 'CNY',
  timezone: 'Asia/Shanghai',
  isDefault: personal,
  role: role,
  memberId: 'member-a',
  joinEpoch: 1,
  version: 1,
  members: [
    SpaceMemberInfo(
      id: 'member-a',
      name: '用户A',
      role: role,
      status: 'active',
      version: 1,
    ),
    if (!single)
      SpaceMemberInfo(
        id: 'member-b',
        name: '用户B',
        role: role == 'owner' ? 'member' : 'owner',
        status: left ? 'left' : 'active',
        version: 1,
      ),
  ],
);

const c4Key = <String, Object?>{
  'id': 'key-a',
  'name': '用户A的示例脚本',
  'display_prefix': 'jiabu_pat_example…',
  'scope': 'read',
  'status': 'active',
  'expires_at': null,
  'created_at': '2026-10-29T00:00:00Z',
  'last_used_at': null,
};
const c4Invitation = <String, Object?>{
  'id': 'invitation-a',
  'space_name': '用户B的空间',
  'inviter_display_name': '用户B',
  'invited_by_member_id': 'member-a',
  'invitee_username': '用户B',
  'status': 'pending',
};

class C4MemorySettings implements SettingsStorage {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

class C4MemorySessions implements SessionStore {
  @override
  Future<String?> read(Partition partition) async => null;
  @override
  Future<void> write(Partition partition, String token) async {}
  @override
  Future<void> delete(Partition partition) async {}
}

class C4NoBiometrics implements BiometricAuthService {
  // Synthetic enrolled device: no platform prompt or real credential access.
  @override
  Future<bool> available() async => true;
  @override
  Future<bool> authenticate(String reason) async => false;
}

AppRuntime c4Runtime({bool online = true, BiometricAuthService? biometrics}) {
  final runtime = AppRuntime(
    databases: DatabaseManager(Directory('fictional-c4-catalog-unused')),
    settings: AppSettingsService(C4MemorySettings()),
    sessions: C4MemorySessions(),
    biometricAuth: biometrics ?? C4NoBiometrics(),
    windowPrivacy: WindowPrivacyService(afterFrame: Future<void>.value),
    device: const DeviceContext(
      appVersion: '0.1.0',
      build: 1,
      model: 'fictional',
      osVersion: 'fictional',
    ),
  );
  runtime.network.online = online;
  runtime.currentSpace = 'space-a';
  runtime.auth.current = AuthSession(
    user: const UserDto(id: 'user-a', username: '用户A', locale: 'zh-Hans'),
    partition: Partition('https://example.invalid', 'user-a'),
    passwordChangeRequired: false,
    generation: 1,
  );
  runtime.lock.scope = runtime.auth.current?.partition.prefix;
  runtime.lock.phase = LockPhase.disabled;
  return runtime;
}

class C4FakeSpaces implements SpacesRepository {
  C4FakeSpaces({SpaceInfo? space}) : space = space ?? c4Space();
  SpaceInfo space;
  String? selected;
  String? failure;
  int pending = 3;
  final actions = <String>[];
  @override
  Stream<List<SpaceInfo>> watch() => Stream.value([space]);
  @override
  Future<int> pendingCount(String spaceId) async => pending;
  @override
  Future<Result<void>> select(String spaceId) async {
    selected = spaceId;
    return const Ok(null);
  }

  @override
  Future<Result<void>> create(
    Map<String, Object?> input,
    String operationId,
  ) async {
    actions.add('create');
    return failure == null ? const Ok(null) : Failure(failure ?? 'network');
  }

  @override
  Future<Result<void>> change(
    SpaceInfo space,
    String action,
    String operationId, {
    Map<String, Object?>? body,
    String? target,
  }) async {
    actions.add(action);
    return failure == null ? const Ok(null) : Failure(failure ?? 'network');
  }

  @override
  Future<Result<List<Map<String, Object?>>>> invitations(
    String? spaceId,
  ) async => const Ok([c4Invitation]);
  @override
  Future<Result<void>> decide(
    String id,
    String operationId, {
    required bool accept,
  }) async {
    actions.add(accept ? 'accept' : 'decline');
    return failure == null ? const Ok(null) : Failure(failure ?? 'network');
  }
}

class C4FakeKeys implements ApiKeysRepository {
  bool plaintextAvailable = true;
  final requests = <Map<String, Object?>>[];
  final actions = <String>[];
  String? failure;
  @override
  Future<Result<List<Map<String, Object?>>>> list() async {
    final rows = [
      c4Key,
      {...c4Key, 'id': 'key-b', 'status': 'revoked'},
      {...c4Key, 'id': 'key-c', 'status': 'expired'},
    ];
    return Ok(rows);
  }

  @override
  Future<Result<Map<String, Object?>>> create(
    Map<String, Object?> input,
    String operationId,
  ) async {
    actions.add('create');
    requests.add(Map.of(input));
    if (!plaintextAvailable) {
      return const Ok({
        'id': 'key-a',
        'created': true,
        'plaintext_available': false,
      });
    }
    return failure == null
        ? const Ok({
            'id': 'key-a',
            'key': 'fictional-key-not-a-credential',
            'created': true,
            'plaintext_available': true,
          })
        : Failure(failure ?? 'network');
  }

  @override
  Future<Result<void>> change(
    String id,
    String operationId, {
    String? name,
  }) async {
    actions.add(name == null ? 'revoke' : 'rename');
    return failure == null ? const Ok(null) : Failure(failure ?? 'network');
  }
}

class C4FixtureViewModel extends C4ViewModel {
  C4FixtureViewModel(this.initial, {this.plaintext});
  final C4UiState initial;
  final String? plaintext;
  @override
  String? get secret => plaintext ?? super.secret;
  @override
  C4UiState build(String formId) {
    super.build(formId);
    return initial;
  }

  bool get _loadSucceeded =>
      initial.error != 'network' && initial.error != 'invalid_response';

  @override
  Future<bool> loadKeys() => Future<bool>.value(_loadSucceeded);
  @override
  Future<bool> loadInvitations(String? spaceId) =>
      Future<bool>.value(_loadSucceeded);
}

class C4Preview extends StatelessWidget {
  const C4Preview({required this.state, this.accent = 'pine', super.key});
  final String state;
  final String accent;
  @override
  Widget build(BuildContext context) {
    final online = !state.contains('offline');
    final runtime = c4Runtime(online: online);
    final member =
        state == 'space_member' || state == 'leave' || state == 'leave_pending';
    final space = c4Space(
      role: member ? 'member' : 'owner',
      personal: state == 'space_personal',
      left: state == 'members_left',
      single: state.startsWith('delete'),
      accent: accent,
    );
    final repository = C4FakeSpaces(space: space);
    runtime
      ..spaces = repository
      ..apiKeys = C4FakeKeys();
    final locked = state.startsWith('unlock');
    runtime.lock.configuration = LockConfiguration(
      enabled: state == 'lock_enabled' || locked,
      mode: state == 'unlock_pattern'
          ? 'pattern'
          : state == 'unlock_biometric'
          ? 'biometric'
          : 'pin',
      waitUntil: state == 'unlock_wait' ? DateTime.utc(2100) : null,
    );
    runtime.lock.phase = locked ? LockPhase.locked : LockPhase.unlocked;
    final (id, child) = c4PreviewBody(state, space);
    final initial = C4UiState(
      online: online,
      copied: state == 'key_copied',
      error: switch (state) {
        'space_validation' => 'validation_failed',
        'password_error' || 'unlock_error' => 'lock_failed',
        'lock_pin_mismatch' => 'mismatch',
        'invitation_expired' => 'invitation_expired',
        'keys_failure' => 'network',
        'key_replay' => 'plaintext_unavailable',
        _ => null,
      },
      values: {
        if (state == 'key_never') 'days': 0,
        if (state == 'unlock_recovery') 'recovery': true,
        if (state == 'lock_pattern_setup') 'mode': 'pattern',
        if (state == 'delete_matched') 'name': space.name,
        if (locked && state != 'unlock_biometric' && state != 'unlock_pattern')
          'use_pin': true,
        if (state == 'switcher') 'accent': accent,
      },
      rows: state == 'keys_list' || state == 'keys_inactive'
          ? [
              c4Key,
              {...c4Key, 'id': 'key-b', 'status': 'revoked'},
              {...c4Key, 'id': 'key-c', 'status': 'expired'},
            ]
          : state.contains('invitations') || state == 'received'
          ? [c4Invitation]
          : [],
    );
    return ProviderScope(
      key: ValueKey('c4-preview-scope:$state'),
      overrides: [
        appRuntimeProvider.overrideWith((ref) => runtime),
        ledgerClockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 29)),
        spacesRepositoryProvider.overrideWithValue(repository),
        deviceTimezoneProvider.overrideWith((ref) async => 'Asia/Shanghai'),
        apiKeysRepositoryProvider.overrideWithValue(
          requireValue<ApiKeysRepository>(runtime.apiKeys),
        ),
        spacesDirectoryProvider.overrideWith((ref) => Stream.value([space])),
        ledgerPresentationSessionProvider.overrideWith(
          (ref) => (partition: 'fictional', spaceId: space.id),
        ),
        c4ViewModelProvider(id).overrideWith(
          () => C4FixtureViewModel(
            initial,
            plaintext: state == 'key_once' || state == 'key_copied'
                ? 'fictional-key-not-a-credential'
                : null,
          ),
        ),
      ],
      child: SizedBox(
        height: 760, // rules:allow-literal fixed C4 preview viewport
        child: Material(
          child: locked || _c4PreviewUsesFullPage(state)
              ? child
              : SingleChildScrollView(child: child),
        ),
      ),
    );
  }
}

bool _c4PreviewUsesFullPage(String state) =>
    (state.startsWith('space_') &&
        !const {
          'space_new',
          'space_edit',
          'space_validation',
        }.contains(state)) ||
    state.startsWith('members') ||
    state.startsWith('settings') ||
    state.startsWith('account') ||
    state.startsWith('password') ||
    state.startsWith('language') ||
    state.startsWith('about') ||
    state.startsWith('lock_') ||
    state.startsWith('keys_') ||
    state == 'sent_invitations' ||
    state.startsWith('received') ||
    state == 'invitation_expired';

(String, Widget) c4PreviewBody(String state, SpaceInfo space) {
  if (const [
    'key_revoke',
    'key_saved_confirm',
    'logout_confirm',
  ].contains(state)) {
    return (
      'confirmation:$state',
      Builder(
        builder: (context) {
          final l = AppLocalizations.of(context);
          return C4Confirmation(
            message: state == 'key_revoke'
                ? l.c4RevokeWarning
                : state == 'key_saved_confirm'
                ? l.c4SavedConfirm
                : l.c4Logout,
            onConfirm: () {},
          );
        },
      ),
    );
  }
  if (state.startsWith('switcher')) {
    return ('switcher', SpacesScreen(page: 'switcher', onSettings: () {}));
  }
  if (state == 'space_new' || state == 'space_validation') {
    return ('space-form:new', const SpaceForm());
  }
  if (state == 'space_edit') {
    return ('space-form:${space.id}', SpaceForm(space: space));
  }
  if (state.startsWith('space_') || state.startsWith('members')) {
    return (
      'space-page',
      SpacesScreen(
        page: state.startsWith('members') ? 'members' : 'settings',
        spaceId: space.id,
      ),
    );
  }
  if (state == 'sent_invitations' ||
      state.startsWith('received') ||
      state == 'invitation_expired') {
    final sent = state == 'sent_invitations';
    return (
      'invitations:${sent ? space.id : 'received'}',
      SpacesScreen(
        page: sent ? 'invitations' : 'received',
        spaceId: sent ? space.id : null,
      ),
    );
  }
  if (state == 'invite' ||
      state.startsWith('leave') ||
      state == 'remove' ||
      state == 'transfer' ||
      state.startsWith('delete')) {
    final action = state.split('_').first;
    final target = state == 'remove' || state == 'transfer' ? 'member-b' : null;
    return (
      '${space.id}:$action:${target ?? ''}',
      SpaceActionForm(
        space: space,
        action: action,
        target: target,
        pending: state == 'leave_pending' ? 3 : 0,
      ),
    );
  }
  if (state.startsWith('lock_')) {
    return ('lock-settings', const LockSettingsScreen());
  }
  if (state.startsWith('unlock')) {
    return ('unlock', const UnlockScreen());
  }
  if (state.startsWith('keys_')) {
    return ('key-list', ApiKeysScreen(showInactive: state == 'keys_inactive'));
  }
  if (state == 'key_details') {
    return ('key-detail:key-a', const ApiKeyDetails(row: c4Key));
  }
  if (state.startsWith('key_')) {
    return ('key-create', const ApiKeyCreate());
  }
  final page = state.split('_').first;
  return ('settings:$page', SettingsScreen(page: page));
}
