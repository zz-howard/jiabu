import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jiabu/app/c4_providers.dart';
import 'package:jiabu/app/providers.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu/shared/c4/c4_form.dart';
import 'package:jiabu/shared/c4/c4_view_model.dart';
import 'package:jiabu/shared/navigation.dart';
import 'package:jiabu_design/jiabu_design.dart';

class LockSettingsScreen extends ConsumerWidget {
  const LockSettingsScreen({super.key});
  static const id = 'lock-settings';
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    ref.watch(lockEventsProvider);
    final lock = ref.watch(appRuntimeProvider).lock;
    final state = ref.watch(c4ViewModelProvider(id));
    final vm = ref.read(c4ViewModelProvider(id).notifier);
    final mode = state.values['mode'] as String? ?? 'biometric';
    final timeout = state.values['timeout'] as int? ?? 1;
    final points = state.values['points'] as List<int>? ?? <int>[];
    final enabled = lock.configuration.enabled;
    return JiabuPageScaffold(
      title: l.c4Lock,
      onBack: () => popOrGo(context, '/settings'),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(context.jiabu.spacing.page),
        child: C4Form(
          id: id,
          title: l.c4Lock,
          showTitle: false,
          requiresOnline: false,
          submitLabel: enabled ? null : l.c4TurnOnAppLock,
          onSubmit: enabled
              ? null
              : () async {
                  final pin = state.values['pin'] as String? ?? '';
                  if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
                    vm.fail('validation_failed');
                    return;
                  }
                  if (pin != state.values['pin_confirm'] ||
                      (mode == 'pattern' &&
                          (points.length < 4 ||
                              points.join() !=
                                  state.values['pattern_first']))) {
                    vm.fail('mismatch');
                    return;
                  }
                  try {
                    final saved = await vm.runLocal(
                      () => lock.configure(
                        pin: pin,
                        mode: mode,
                        timeoutMinutes: timeout,
                        pattern: mode == 'pattern' ? points.join() : null,
                      ),
                    );
                    if (saved && context.mounted) {
                      ref.invalidate(c4ViewModelProvider(id));
                    }
                  } on Object {
                    vm.fail('local_storage_unavailable');
                  }
                },
          children: [
            JiabuStackItem.content(
              child: Text(enabled ? l.c4Enabled : l.c4Disabled),
            ),
            JiabuStackItem.caption(child: Text(l.c4LockPrivacy)),
            if (enabled)
              JiabuStackItem.action(
                child: OutlinedButton(
                  onPressed: lock.disable,
                  child: Text(l.c4TurnOffAppLock),
                ),
              )
            else ...[
              JiabuStackItem.content(
                child: Wrap(
                  children: [
                    for (final entry in {
                      'biometric': l.c4Biometric,
                      'pattern': l.c4Pattern,
                      'pin': l.c4Pin,
                    }.entries)
                      ChoiceChip(
                        label: Text(entry.value),
                        selected: mode == entry.key,
                        onSelected: (_) => vm.patch('mode', entry.key),
                      ),
                  ],
                ),
              ),
              JiabuStackItem.content(
                child: C4Field(
                  id: id,
                  field: 'pin',
                  label: l.c4PinPrompt,
                  obscure: true,
                  keyboard: TextInputType.number,
                ),
              ),
              JiabuStackItem.content(
                child: C4Field(
                  id: id,
                  field: 'pin_confirm',
                  label: l.c4PinConfirm,
                  obscure: true,
                  keyboard: TextInputType.number,
                ),
              ),
              if (mode == 'pattern') ...[
                JiabuStackItem.content(
                  child: Text(
                    state.values['pattern_first'] == null
                        ? l.c4PatternPrompt
                        : l.c4PatternConfirm,
                  ),
                ),
                JiabuStackItem.content(
                  child: PatternLock(
                    points: points,
                    label: l.c4Pattern,
                    onChanged: (value) => vm.patch('points', value),
                  ),
                ),
                JiabuStackItem.action(
                  child: TextButton(
                    onPressed: () => vm.patch('points', <int>[]),
                    child: Text(l.c4Clear),
                  ),
                ),
                JiabuStackItem.action(
                  child: TextButton(
                    onPressed: points.length < 4
                        ? null
                        : () {
                            vm
                              ..patch('pattern_first', points.join())
                              ..patch('points', <int>[]);
                          },
                    child: Text(l.c4PatternConfirm),
                  ),
                ),
              ],
              JiabuStackItem.content(child: Text(l.c4Timeout)),
              JiabuStackItem.content(
                child: Wrap(
                  children: [
                    for (final entry in {
                      0: l.c4Immediately,
                      1: l.c4Minute1,
                      5: l.c4Minutes5,
                      15: l.c4Minutes15,
                    }.entries)
                      ChoiceChip(
                        label: Text(entry.value),
                        selected: timeout == entry.key,
                        onSelected: (_) => vm.patch('timeout', entry.key),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
