import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu/shared/c4/c4_confirmation.dart';
import 'package:jiabu/shared/c4/c4_form.dart';
import 'package:jiabu/shared/c4/c4_view_model.dart';
import 'package:jiabu_design/jiabu_design.dart';

class ApiKeyCreate extends ConsumerWidget {
  const ApiKeyCreate({this.formId = 'key-create', super.key});
  final String formId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = formId;
    final l = AppLocalizations.of(context);
    final state = ref.watch(c4ViewModelProvider(id));
    final vm = ref.read(c4ViewModelProvider(id).notifier);
    final key = vm.secret;
    return PopScope(
      canPop: key == null && !state.busy,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || key == null) {
          return;
        }
        final confirmed = await JiabuSheet.show<bool>(
          context: context,
          builder: (sheetContext) => C4Confirmation(
            message: l.c4SavedConfirm,
            onConfirm: () => Navigator.of(sheetContext).pop(true),
          ),
        );
        if (confirmed == true && context.mounted) {
          await vm.forgetKey();
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: C4Form(
        id: id,
        title: key == null ? l.c4CreateKey : l.c4KeyOnce,
        requiresOnline: key == null,
        submitLabel: key == null ? l.c4Create : l.c4Saved,
        onSubmit: () async {
          if (key == null) {
            await vm.createKey();
          } else {
            await vm.forgetKey();
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          }
        },
        children: key == null
            ? [
                JiabuStackItem.content(
                  child: C4Field(id: id, field: 'name', label: l.c4Name),
                ),
                JiabuStackItem.content(child: Text(l.c4Expiry)),
                JiabuStackItem.content(
                  child: JiabuChipGroup(
                    children: [
                      for (final entry in {
                        7: l.c4Days7,
                        30: l.c4Days30,
                        90: l.c4Days90,
                        365: l.c4Year,
                        0: l.c4Never,
                      }.entries)
                        ChoiceChip(
                          label: Text(entry.value),
                          selected: (state.values['days'] ?? 90) == entry.key,
                          onSelected:
                              state.values['_frozen'] == true || state.busy
                              ? null
                              : (_) => vm.patch('days', entry.key),
                        ),
                    ],
                  ),
                ),
                if (state.values['days'] == 0)
                  JiabuStackItem.captionAfter(
                    child: PaperCard(child: Text(l.c4NeverWarning)),
                  ),
                JiabuStackItem.content(child: Text(l.c4Scope)),
                for (final entry in {
                  'read': l.c4Read,
                  'read_write': l.c4ReadWrite,
                }.entries)
                  JiabuStackItem.content(
                    child: Card(
                      child: ListTile(
                        title: Text(entry.value),
                        subtitle: Text(
                          entry.key == 'read' ? l.c4ReadHelp : l.c4WriteHelp,
                        ),
                        selected: state.values['scope'] == entry.key,
                        trailing: state.values['scope'] == entry.key
                            ? const Text('✓')
                            : null,
                        onTap: state.values['_frozen'] == true || state.busy
                            ? null
                            : () => vm.patch('scope', entry.key),
                      ),
                    ),
                  ),
                JiabuStackItem.captionAfter(child: Text(l.c4KeyScopeHelp)),
                JiabuStackItem.captionAfter(child: Text(l.c4KeyOnceHelp)),
              ]
            : [
                JiabuStackItem.content(
                  child: ApiKeyCard(
                    child: JiabuStack(
                      children: [
                        JiabuStackItem.content(
                          child: Actions(
                            actions: <Type, Action<Intent>>{
                              CopySelectionTextIntent:
                                  CallbackAction<CopySelectionTextIntent>(
                                    onInvoke: (intent) {
                                      unawaited(vm.copyKey());
                                      return null;
                                    },
                                  ),
                            },
                            child: Focus(
                              onKeyEvent: (node, event) {
                                final keyboard = HardwareKeyboard.instance;
                                final copy =
                                    (event.logicalKey ==
                                            LogicalKeyboardKey.keyC &&
                                        (keyboard.isControlPressed ||
                                            keyboard.isMetaPressed)) ||
                                    (event.logicalKey ==
                                            LogicalKeyboardKey.insert &&
                                        keyboard.isControlPressed);
                                if ((event is KeyDownEvent ||
                                        event is KeyRepeatEvent) &&
                                    copy) {
                                  unawaited(vm.copyKey());
                                  return KeyEventResult.handled;
                                }
                                return KeyEventResult.ignored;
                              },
                              child: SelectableText(
                                key,
                                style: context.jiabu.type.mono.copyWith(
                                  fontSize: context.jiabu.type.body.fontSize,
                                ),
                                contextMenuBuilder: (context, editableState) =>
                                    AdaptiveTextSelectionToolbar.buttonItems(
                                      anchors: editableState.contextMenuAnchors,
                                      buttonItems: [
                                        ContextMenuButtonItem(
                                          label: l.c4Copy,
                                          onPressed: () {
                                            editableState.hideToolbar();
                                            unawaited(vm.copyKey());
                                          },
                                        ),
                                      ],
                                    ),
                              ),
                            ),
                          ),
                        ),
                        JiabuStackItem.action(
                          child: OutlinedButton(
                            onPressed: vm.copyKey,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: state.copied
                                  ? context.jiabu.colors.pos
                                  : context.jiabu.colors.primaryText,
                            ),
                            child: Text(state.copied ? l.c4Copied : l.c4Copy),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                JiabuStackItem.captionAfter(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.jiabu.colors.warnSoft,
                      borderRadius: BorderRadius.circular(
                        context.jiabu.decor.cardRadius,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(JiabuSpacing.cardGap),
                      child: Text(
                        l.c4KeyOnceWarning,
                        style: context.jiabu.type.secondary.copyWith(
                          color: context.jiabu.colors.warn,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
      ),
    );
  }
}
