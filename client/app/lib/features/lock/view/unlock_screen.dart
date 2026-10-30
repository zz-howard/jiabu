import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jiabu/app/c4_providers.dart';
import 'package:jiabu/app/providers.dart';
import 'package:jiabu/domain/app_lock.dart';
import 'package:jiabu/domain/result.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu/shared/c4/c4_form.dart';
import 'package:jiabu/shared/c4/c4_labels.dart';
import 'package:jiabu/shared/c4/c4_view_model.dart';
import 'package:jiabu_design/jiabu_design.dart';

class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});
  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  static const id = 'unlock';
  bool _requestedBiometric = false;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    ref.watch(lockEventsProvider);
    final runtime = ref.watch(appRuntimeProvider);
    final lock = runtime.lock;
    final state = ref.watch(c4ViewModelProvider(id));
    final vm = ref.read(c4ViewModelProvider(id).notifier);
    final pin = state.values['pin'] as String? ?? '';
    final points = (state.values['points'] as List<int>?) ?? <int>[];
    final usePin =
        state.values['use_pin'] == true || lock.configuration.mode == 'pin';
    final enabled = lock.phase == LockPhase.locked && !lock.waiting;
    Future<void> verify({String? reason}) async {
      final accepted = await lock.authenticate(
        value: usePin ? pin : points.join(),
        kind: usePin ? 'pin' : 'pattern',
        reason: reason,
      );
      if (mounted) {
        vm.patch('pin', '');
        if (accepted) {
          vm.patch('points', <int>[]);
        }
        if (!accepted) {
          vm.fail(lock.waiting ? 'lock_wait' : 'lock_failed');
        }
      }
    }

    if (!_requestedBiometric && lock.configuration.mode == 'biometric') {
      _requestedBiometric = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(() async {
            if (!await lock.biometrics.available()) {
              if (mounted) {
                vm.patch('use_pin', true);
              }
              return;
            }
            if (mounted) {
              await verify(reason: l.c4Authenticate);
            }
          }());
        }
      });
    }
    return PaperBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.jiabu.spacing.page),
          child: JiabuStack(
            children: [
              const JiabuStackItem.content(child: JiabuLogo()),
              JiabuStackItem.content(child: HandText(l.handC4Locked)),
              if (lock.waiting)
                JiabuStackItem.captionBefore(child: Text(l.c4LockWait)),
              if (state.error case final String error)
                JiabuStackItem.captionBefore(child: Text(c4Error(l, error))),
              if (state.values['recovery'] != true) ...[
                if (usePin)
                  JiabuStackItem.content(
                    child: LockErrorMotion(
                      error: state.error != null,
                      child: PinPad(
                        length: pin.length,
                        enabled: enabled,
                        deleteLabel: l.c4Backspace,
                        onDigit: (digit) {
                          if (pin.length < 6) {
                            vm.patch('pin', '$pin$digit');
                          }
                        },
                        onDelete: () => vm.patch(
                          'pin',
                          pin.isEmpty ? '' : pin.substring(0, pin.length - 1),
                        ),
                      ),
                    ),
                  )
                else if (lock.configuration.mode == 'pattern') ...[
                  JiabuStackItem.content(
                    child: LockErrorMotion(
                      error: state.error != null,
                      child: PatternLock(
                        points: points,
                        label: l.c4Pattern,
                        enabled: enabled,
                        error: state.error != null,
                        onChanged: (value) => vm.patch('points', value),
                      ),
                    ),
                  ),
                  JiabuStackItem.action(
                    child: TextButton(
                      onPressed: () => vm.patch('points', <int>[]),
                      child: Text(l.c4Clear),
                    ),
                  ),
                ] else
                  JiabuStackItem.action(
                    child: OutlinedButton(
                      onPressed: enabled
                          ? () => verify(reason: l.c4Authenticate)
                          : null,
                      child: Text(l.c4Biometric),
                    ),
                  ),
                JiabuStackItem.action(
                  child: FilledButton(
                    onPressed:
                        enabled &&
                            (usePin ? pin.length >= 4 : points.length >= 4)
                        ? verify
                        : null,
                    child: Text(l.c4Unlock),
                  ),
                ),
                JiabuStackItem.action(
                  child: TextButton(
                    onPressed: () => vm.patch('use_pin', true),
                    child: Text(l.c4UsePin),
                  ),
                ),
                JiabuStackItem.action(
                  child: TextButton(
                    onPressed: () => vm.patch('recovery', true),
                    child: Text(l.c4ForgotPin),
                  ),
                ),
              ],
              if (state.values['recovery'] == true) ...[
                JiabuStackItem.action(
                  child: TextButton(
                    onPressed: () {
                      vm
                        ..patch('password', '')
                        ..patch('recovery', false);
                    },
                    child: Text(l.c4Back),
                  ),
                ),
                JiabuStackItem.content(
                  child: C4Field(
                    id: id,
                    field: 'password',
                    label: l.c4CurrentPassword,
                    obscure: true,
                  ),
                ),
                JiabuStackItem.action(
                  child: FilledButton(
                    onPressed: () async {
                      final session = runtime.auth.current;
                      final saved =
                          session?.partition ??
                          await runtime.settings.current();
                      final username = session?.user.username ?? '';
                      if (saved == null || username.isEmpty) {
                        // Use the existing login without a cached identity.
                        // Retain the lock until password login succeeds.
                        await runtime.auth.logout();
                        return;
                      }
                      final result = await runtime.auth.login(
                        saved.server,
                        username,
                        state.values['password'] as String? ?? '',
                      );
                      if (result is Ok<Object?> &&
                          runtime.auth.current?.partition.prefix ==
                              saved.prefix) {
                        final authenticated = runtime.auth.current;
                        await runtime.sessionWork;
                        if (identical(runtime.auth.current, authenticated) &&
                            lock.scope == saved.prefix &&
                            authenticated?.passwordChangeRequired == false) {
                          await lock.resetAfterPasswordLogin();
                        }
                      } else if (mounted) {
                        vm.fail('lock_failed');
                      }
                    },
                    child: Text(l.c4Confirm),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
