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
    unawaited(Future<void>.microtask(_load));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(c4ViewModelProvider(id));
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.jiabu.decor.pageInset),
      child: C4Form(
        id: id,
        title: l.c4Keys,
        children: [
          Text(l.c4KeysSubtitle, style: context.jiabu.type.secondary),
          if (state.online) ...[
            if (state.rows.isEmpty) Text(state.busy ? l.c4Loading : l.c4Empty),
            for (final row in state.rows.where(
              (row) => row['status'] == 'active',
            ))
              ApiKeyRow(
                row: row,
                onTap: () async {
                  await PaperSheet.show<void>(
                    context: context,
                    builder: (_) => ApiKeyDetails(row: row),
                    wrapperBuilder: (_, child) => C4ScopeFence(child: child),
                  );
                  if (mounted) {
                    await _load();
                  }
                },
              ),
            ExpansionTile(
              initiallyExpanded: widget.showInactive,
              title: Text(l.c4Inactive),
              trailing: const JiabuIcon(JiabuIcons.uiDown),
              children: [
                for (final row in state.rows.where(
                  (row) => row['status'] != 'active',
                ))
                  ApiKeyRow(row: row),
              ],
            ),
          ],
          if (_loadFailed)
            TextButton(
              onPressed: state.online && !state.busy ? _load : null,
              child: Text(l.c4Retry),
            ),
          FilledButton(
            onPressed: !state.online || state.busy
                ? null
                : () async {
                    final formId = 'key-create:${const Uuid().v7()}';
                    await PaperSheet.show<void>(
                      context: context,
                      dismissible: false,
                      builder: (_) => ApiKeyCreate(formId: formId),
                      wrapperBuilder: (_, child) => C4ScopeFence(child: child),
                    );
                    if (mounted) {
                      await _load();
                    }
                  },
            child: Text(l.c4CreateKey),
          ),
        ],
      ),
    );
  }
}
