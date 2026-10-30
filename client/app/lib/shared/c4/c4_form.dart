import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu/shared/c4/c4_labels.dart';
import 'package:jiabu/shared/c4/c4_view_model.dart';
import 'package:jiabu_design/jiabu_design.dart';

export 'package:jiabu/shared/c4/c4_field.dart';

class C4Form extends ConsumerWidget {
  const C4Form({
    required this.id,
    required this.title,
    required this.children,
    this.onSubmit,
    this.submitLabel,
    this.requiresOnline = true,
    this.enabled = true,
    this.showTitle = true,
    super.key,
  });
  final String id;
  final String title;
  final List<JiabuStackItem> children;
  final Future<void> Function()? onSubmit;
  final String? submitLabel;
  final bool requiresOnline;
  final bool enabled;
  final bool showTitle;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(c4ViewModelProvider(id));
    return JiabuStack(
      children: [
        if (showTitle)
          JiabuStackItem.content(
            child: HandUnderline(
              child: Text(title, style: context.jiabu.type.sectionTitle),
            ),
          ),
        ...children,
        if (requiresOnline && !state.online)
          JiabuStackItem.caption(child: Text(l.c4Offline)),
        if (state.error case final String code)
          JiabuStackItem.caption(
            child: Semantics(liveRegion: true, child: Text(c4Error(l, code))),
          ),
        if (onSubmit != null)
          JiabuStackItem.action(
            child: FilledButton(
              onPressed:
                  enabled && !state.busy && (!requiresOnline || state.online)
                  ? onSubmit
                  : null,
              child: Text(submitLabel ?? l.c4Save),
            ),
          ),
      ],
    );
  }
}
