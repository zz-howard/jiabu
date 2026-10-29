import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/services/biometric_auth_service.dart';
import 'package:jiabu/domain/app_lock.dart';
import 'package:jiabu/domain/result.dart';
import 'package:jiabu/features/catalog/c4_cases.dart';
import 'package:jiabu/features/lock/view/app_lock_gate.dart';
import 'package:jiabu/features/settings/api_keys/api_keys_screen.dart';
import 'package:jiabu/features/spaces/view/spaces_screen.dart';
import 'package:jiabu/shared/c4/c4_view_model.dart';
import 'package:jiabu_design/jiabu_design.dart';

import '../support/c4_harness.dart';

class UnenrolledBiometrics implements BiometricAuthService {
  int prompts = 0;
  @override
  Future<bool> available() async => false;
  @override
  Future<bool> authenticate(String reason) async {
    prompts++;
    return false;
  }
}

class OtherInviterSpaces extends C4FakeSpaces {
  @override
  Future<Result<List<Map<String, Object?>>>> invitations(
    String? spaceId,
  ) async {
    final invitation = Map<String, Object?>.of(c4Invitation)
      ..['invited_by_member_id'] = 'member-b';
    return Ok([invitation]);
  }
}

class FailingInvitationsSpaces extends C4FakeSpaces {
  @override
  Future<Result<List<Map<String, Object?>>>> invitations(
    String? spaceId,
  ) async => const Failure('network');
}

void main() {
  testWidgets('leave_shows_pending_count_before_sending_request', (
    tester,
  ) async {
    final runtime = c4Runtime();
    final spaces = C4FakeSpaces(space: c4Space(role: 'member'));
    await pumpC4Widget(
      tester,
      runtime: runtime,
      spaces: spaces,
      keys: C4FakeKeys(),
      child: const SpacesScreen(page: 'settings', spaceId: 'space-a'),
    );
    await tester.ensureVisible(find.text('退出空间'));
    await tester.tap(find.text('退出空间'));
    await tester.pumpAndSettle();
    expect(find.text('有 3 条还没上传，退出后会丢弃'), findsOneWidget);
    expect(spaces.actions, isEmpty);
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(spaces.actions, ['leave']);
  });
  testWidgets('offline_member_management_buttons_are_disabled', (tester) async {
    final spaces = C4FakeSpaces();
    await pumpC4Widget(
      tester,
      runtime: c4Runtime(online: false),
      spaces: spaces,
      keys: C4FakeKeys(),
      child: const SpacesScreen(page: 'settings', spaceId: 'space-a'),
    );
    for (final text in ['改名与点缀色', '邀请成员', '移除成员', '转让所有者', '退出空间']) {
      final button = find.ancestor(
        of: find.text(text),
        matching: find.bySubtype<ButtonStyleButton>(),
      );
      expect(button, findsOneWidget);
      expect(tester.widget<ButtonStyleButton>(button).onPressed, isNull);
    }
    expect(spaces.actions, isEmpty);
  });
  testWidgets('member_cannot_invite_or_manage_personal_hides_all', (
    tester,
  ) async {
    await pumpC4Widget(
      tester,
      runtime: c4Runtime(),
      spaces: C4FakeSpaces(space: c4Space(role: 'member')),
      keys: C4FakeKeys(),
      child: const SpacesScreen(page: 'settings', spaceId: 'space-a'),
    );
    expect(find.text('移除成员'), findsNothing);
    expect(find.text('转让所有者'), findsNothing);
    // P71: only the owner invites and sees sent invitations.
    expect(find.text('邀请成员'), findsNothing);
    expect(find.text('发出的邀请'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await pumpC4Widget(
      tester,
      runtime: c4Runtime(),
      spaces: C4FakeSpaces(space: c4Space(personal: true)),
      keys: C4FakeKeys(),
      child: const SpacesScreen(page: 'settings', spaceId: 'space-a'),
    );
    expect(find.text('邀请成员'), findsNothing);
    expect(find.text('退出空间'), findsNothing);
    expect(find.text('删除空间'), findsNothing);
  });
  for (final accept in [true, false]) {
    testWidgets(
      'received_invitation_${accept ? 'accept' : 'decline'}_calls_repository',
      (tester) async {
        final spaces = C4FakeSpaces();
        await pumpC4Widget(
          tester,
          runtime: c4Runtime(),
          spaces: spaces,
          keys: C4FakeKeys(),
          child: const InvitationsBody(),
        );
        await tester.tap(find.text(accept ? '接受' : '拒绝'));
        await tester.pumpAndSettle();
        expect(spaces.actions, [if (accept) 'accept' else 'decline']);
      },
    );
  }
  testWidgets('invalid_invitation_displays_localized_expiry', (tester) async {
    final spaces = C4FakeSpaces()..failure = 'not_found';
    await pumpC4Widget(
      tester,
      runtime: c4Runtime(),
      spaces: spaces,
      keys: C4FakeKeys(),
      child: const InvitationsBody(),
    );
    await tester.tap(find.text('接受'));
    await tester.pumpAndSettle();
    expect(find.text('邀请已失效'), findsOneWidget);
    expect(find.text('重试'), findsNothing);
  });
  testWidgets('invitation_load_failure_shows_retry', (tester) async {
    await pumpC4Widget(
      tester,
      runtime: c4Runtime(),
      spaces: FailingInvitationsSpaces(),
      keys: C4FakeKeys(),
      child: const InvitationsBody(),
    );
    expect(find.text('重试'), findsOneWidget);
  });
  for (final action in ['remove', 'transfer', 'leave']) {
    testWidgets('${action}_server_error_remains_visible', (tester) async {
      final spaces = C4FakeSpaces()..failure = 'version_conflict';
      final space = c4Space(role: action == 'leave' ? 'member' : 'owner');
      await pumpC4Widget(
        tester,
        runtime: c4Runtime(),
        spaces: spaces,
        keys: C4FakeKeys(),
        child: SpaceActionForm(
          space: space,
          action: action,
          target: 'member-b',
        ),
      );
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect(find.text('内容已被修改，请刷新后重试。'), findsOneWidget);
      expect(spaces.actions, [action]);
    });
  }
  testWidgets('owner_cancels_any_invitation_former_owner_only_its_own', (
    tester,
  ) async {
    Future<void> pump(C4FakeSpaces spaces, String role) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await pumpC4Widget(
        tester,
        runtime: c4Runtime(),
        spaces: spaces,
        keys: C4FakeKeys(),
        child: InvitationsBody(space: c4Space(role: role)),
      );
    }

    // P71: the current owner may withdraw any pending invitation.
    await pump(C4FakeSpaces(), 'owner');
    expect(find.text('取消邀请'), findsOneWidget);
    await pump(OtherInviterSpaces(), 'owner');
    expect(find.text('取消邀请'), findsOneWidget);
    // A former owner keeps withdrawing only what it sent before the transfer.
    await pump(C4FakeSpaces(), 'member');
    expect(find.text('取消邀请'), findsOneWidget);
    await pump(OtherInviterSpaces(), 'member');
    expect(find.text('取消邀请'), findsNothing);
  });
  testWidgets('delete_requires_exact_name_and_default_space_hides_delete', (
    tester,
  ) async {
    final space = c4Space(single: true);
    await pumpC4Widget(
      tester,
      runtime: c4Runtime(),
      spaces: C4FakeSpaces(space: space),
      keys: C4FakeKeys(),
      child: SpaceActionForm(space: space, action: 'delete'),
    );
    final confirm = find.ancestor(
      of: find.text('确认'),
      matching: find.byType(FilledButton),
    );
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.enterText(find.byType(TextFormField), '${space.name} ');
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.enterText(find.byType(TextFormField), space.name);
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
  });
  testWidgets('key_secret_is_cleared_and_cannot_reappear', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('jiabu/window_privacy'),
          (_) async => null,
        );
    const clipboardChannel = MethodChannel('jiabu/secure_clipboard');
    final clips = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(clipboardChannel, (call) async {
          clips.add(call);
          return null;
        });
    final keys = C4FakeKeys();
    final container = await pumpC4Widget(
      tester,
      runtime: c4Runtime(),
      spaces: C4FakeSpaces(),
      keys: keys,
      child: const ApiKeyCreate(),
    );
    final vm = container.read(c4ViewModelProvider('key-create').notifier)
      ..patch('name', '用户A')
      ..patch('scope', 'read');
    expect(await vm.createKey(), isTrue);
    await tester.pump();
    expect(find.text('fictional-key-not-a-credential'), findsOneWidget);
    await tester.tap(find.text('复制'));
    await tester.pumpAndSettle();
    expect(find.text('已复制 ✓'), findsOneWidget);
    expect(
      (clips.single.arguments as Map<Object?, Object?>)['sensitive'],
      true,
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('复制'), findsOneWidget);
    await vm.forgetKey();
    await tester.pump();
    expect(vm.secret, isNull);
    expect(find.text('fictional-key-not-a-credential'), findsNothing);
    expect(
      container.read(c4ViewModelProvider('key-create')).toString(),
      isNot(contains('fictional-key-not-a-credential')),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('jiabu/window_privacy'),
          null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(clipboardChannel, null);
  });
  testWidgets('unenrolled_biometrics_go_directly_to_pin_without_prompt', (
    tester,
  ) async {
    final biometrics = UnenrolledBiometrics();
    final runtime = c4Runtime(biometrics: biometrics);
    runtime.lock.configuration = const LockConfiguration(enabled: true);
    runtime.lock.phase = LockPhase.locked;
    await pumpC4Widget(
      tester,
      runtime: runtime,
      spaces: C4FakeSpaces(),
      keys: C4FakeKeys(),
      child: const AppLockGate(child: Text('fictional private content')),
    );
    expect(find.byType(PinPad), findsOneWidget);
    expect(find.text('fictional private content'), findsNothing);
    expect(biometrics.prompts, 0);
  });
  testWidgets('lock_gate_removes_business_content_and_uses_placeholder', (
    tester,
  ) async {
    final runtime = c4Runtime();
    runtime.lock.configuration = const LockConfiguration(
      enabled: true,
      mode: 'pin',
    );
    runtime.lock.phase = LockPhase.locked;
    await pumpC4Widget(
      tester,
      runtime: runtime,
      spaces: C4FakeSpaces(),
      keys: C4FakeKeys(),
      child: const AppLockGate(child: Text('fictional private amount 900')),
    );
    expect(find.text('fictional private amount 900'), findsNothing);
    expect(find.byType(JiabuLogoSealPlaceholder), findsOneWidget);
  });
}
