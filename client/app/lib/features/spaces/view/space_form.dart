import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jiabu/app/c4_providers.dart';
import 'package:jiabu/domain/required_value.dart';
import 'package:jiabu/domain/spaces.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu/shared/c4/c4_form.dart';
import 'package:jiabu/shared/c4/c4_scope_fence.dart';
import 'package:jiabu/shared/c4/c4_view_model.dart';
import 'package:jiabu_design/jiabu_design.dart';

Future<void> openSpaceForm(BuildContext context, {SpaceInfo? space}) =>
    JiabuSheet.show<void>(
      context: context,
      builder: (_) => SpaceForm(space: space),
      wrapperBuilder: (_, child) => C4ScopeFence(child: child),
    );

class SpaceForm extends ConsumerWidget {
  const SpaceForm({this.space, super.key});
  final SpaceInfo? space;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final zone = space == null ? ref.watch(deviceTimezoneProvider) : null;
    if (zone?.isLoading == true) {
      return Text(l.c4Loading);
    }
    final timezone = zone?.asData?.value ?? 'UTC';
    final used =
        (ref.watch(spacesDirectoryProvider).asData?.value ?? <SpaceInfo>[])
            .map((space) => space.accent)
            .toSet();
    final defaultAccent =
        context.jiabu.colors.spaceAccents.keys
            .where((key) => !used.contains(key))
            .firstOrNull ??
        'terracotta';
    final id = 'space-form:${space?.id ?? 'new'}';
    final state = ref.watch(c4ViewModelProvider(id));
    final vm = ref.read(c4ViewModelProvider(id).notifier);
    return C4Form(
      id: id,
      title: space == null ? l.c4CreateSpace : l.c4Edit,
      onSubmit: () async {
        final values = state.values;
        final name = (values['name'] as String? ?? space?.name ?? '').trim();
        if (name.isEmpty || name.runes.length > 40) {
          vm.fail('validation_failed');
          return;
        }
        final body = <String, Object?>{
          'name': name,
          'accent_color':
              values['accent_color'] ?? space?.accent ?? defaultAccent,
          if (space == null) ...{
            'id': vm.operationId,
            'currency': values['currency'] ?? 'CNY',
            'timezone': values['timezone'] ?? timezone,
          } else
            'expected_version': space?.version,
        };
        final repository = ref.read(spacesRepositoryProvider);
        final saved = await vm.run(
          () => space == null
              ? repository.create(body, vm.operationId)
              : repository.change(
                  requireValue<SpaceInfo>(space),
                  'edit',
                  vm.operationId,
                  body: body,
                ),
        );
        if (saved && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      children: [
        JiabuStackItem.content(
          child: C4Field(
            id: id,
            field: 'name',
            label: l.c4Name,
            initial: space?.name ?? '',
          ),
        ),
        JiabuStackItem.content(
          child: SpaceAccentPicker(
            value:
                state.values['accent_color'] as String? ??
                space?.accent ??
                defaultAccent,
            label: l.c4Accent,
            names: {
              'terracotta': l.c4AccentTerracotta,
              'indigo': l.c4AccentIndigo,
              'pine': l.c4AccentPine,
              'plum': l.c4AccentPlum,
              'teal': l.c4AccentTeal,
              'amber': l.c4AccentAmber,
              'rouge': l.c4AccentRouge,
              'wisteria': l.c4AccentWisteria,
            },
            onChanged: (value) => vm.patch('accent_color', value),
          ),
        ),
        if (space == null) ...[
          JiabuStackItem.content(child: Text(l.c4Currency)),
          JiabuStackItem.content(
            child: JiabuChipGroup(
              children: [
                for (final currency in const [
                  'CNY',
                  'HKD',
                  'USD',
                  'EUR',
                  'GBP',
                  'JPY',
                ])
                  ChoiceChip(
                    label: Text(currency),
                    selected: (state.values['currency'] ?? 'CNY') == currency,
                    onSelected: (_) => vm.patch('currency', currency),
                  ),
              ],
            ),
          ),
          JiabuStackItem.content(
            child: C4Field(
              id: id,
              field: 'timezone',
              label: l.c4Timezone,
              initial: timezone,
            ),
          ),
        ],
      ],
    );
  }
}
