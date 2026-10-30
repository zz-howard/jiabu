import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jiabu/features/settings/api_keys/api_key_create.dart';
import 'package:jiabu/features/settings/api_keys/api_key_details.dart';
import 'package:jiabu/features/settings/api_keys/api_key_row.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu/shared/c4/c4_form.dart';
import 'package:jiabu/shared/c4/c4_scope_fence.dart';
import 'package:jiabu/shared/c4/c4_view_model.dart';
import 'package:jiabu/shared/navigation.dart';
import 'package:jiabu_design/jiabu_design.dart';
import 'package:uuid/uuid.dart';

export 'package:jiabu/features/settings/api_keys/api_key_create.dart';
export 'package:jiabu/features/settings/api_keys/api_key_details.dart';
export 'package:jiabu/features/settings/api_keys/api_key_row.dart';

class ApiKeysScreen extends ConsumerStatefulWidget {
  const ApiKeysScreen({this.showInactive = false, super.key});
  final bool showInactive;
  @override
  ConsumerState<ApiKeysScreen> createState() => _ApiKeysScreenState();
}

class _ApiKeysScreenState extends ConsumerState<ApiKeysScreen> {
  static const id = 'key-list';
  bool _loadFailed = false;
  late bool _inactiveExpanded;

  Future<void> _load() async {
    if (!mounted) {
      return;
    }
    if (_loadFailed) {
      setState(() => _loadFailed = false);
    }
    final success = await ref.read(c4ViewModelProvider(id).notifier).loadKeys();
    if (!mounted) {
      return;
    }
    final error = ref.read(c4ViewModelProvider(id)).error;
    setState(() => _loadFailed = !success && error != 'offline');
  }

  @override
  void initState() {
    super.initState();
    _inactiveExpanded = widget.showInactive;
    unawaited(Future<void>.microtask(_load));
  }

  @override
  void didUpdateWidget(covariant ApiKeysScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showInactive != widget.showInactive) {
      _inactiveExpanded = widget.showInactive;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(c4ViewModelProvider(id));
    return JiabuPageScaffold(
      title: l.c4Keys,
      onBack: () => popOrGo(context, '/settings'),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(context.jiabu.spacing.page),
        child: C4Form(
          id: id,
          title: l.c4Keys,
          showTitle: false,
          children: [
            JiabuStackItem.content(child: HandText(l.handC4KeysSubtitle)),
            if (state.online) ...[
              if (state.rows.isEmpty)
                JiabuStackItem.content(
                  child: JiabuEmptyState(
                    message: state.busy
                        ? Text(l.c4Loading)
                        : HandText(
                            l.handNothingHere,
                            textAlign: TextAlign.center,
                          ),
                  ),
                ),
              if (state.rows.any((row) => row['status'] == 'active'))
                JiabuStackItem.content(
                  child: JiabuSettingsGroup(
                    children: [
                      for (final row in state.rows.where(
                        (row) => row['status'] == 'active',
                      ))
                        ApiKeyRow(
                          row: row,
                          onTap: () async {
                            await JiabuSheet.show<void>(
                              context: context,
                              builder: (_) => ApiKeyDetails(row: row),
                              wrapperBuilder: (_, child) =>
                                  C4ScopeFence(child: child),
                            );
                            if (mounted) {
                              await _load();
                            }
                          },
                        ),
                    ],
                  ),
                ),
              JiabuStackItem.content(
                child: JiabuSettingsGroup(
                  children: [
                    Semantics(
                      key: const Key('inactive-keys-toggle'),
                      expanded: _inactiveExpanded,
                      child: JiabuListRow(
                        title: l.c4Inactive,
                        trailing: JiabuIcon(
                          JiabuIcons.uiDown,
                          flipY: _inactiveExpanded,
                        ),
                        onTap: () => setState(
                          () => _inactiveExpanded = !_inactiveExpanded,
                        ),
                      ),
                    ),
                    if (_inactiveExpanded)
                      for (final row in state.rows.where(
                        (row) => row['status'] != 'active',
                      ))
                        ApiKeyRow(row: row),
                  ],
                ),
              ),
            ],
            if (_loadFailed)
              JiabuStackItem.action(
                child: TextButton(
                  onPressed: state.online && !state.busy ? _load : null,
                  child: Text(l.c4Retry),
                ),
              ),
            JiabuStackItem.action(
              child: FilledButton(
                onPressed: !state.online || state.busy
                    ? null
                    : () async {
                        final formId = 'key-create:${const Uuid().v7()}';
                        await JiabuSheet.show<void>(
                          context: context,
                          dismissible: false,
                          builder: (_) => ApiKeyCreate(formId: formId),
                          wrapperBuilder: (_, child) =>
                              C4ScopeFence(child: child),
                        );
                        if (mounted) {
                          await _load();
                        }
                      },
                child: Text(l.c4CreateKey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
