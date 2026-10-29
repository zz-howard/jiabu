import 'package:flutter/material.dart';
import 'package:jiabu_design/src/components/hand_text.dart';
import 'package:jiabu_design/src/components/ledger_controls.dart';
import 'package:jiabu_design/src/theme_context.dart';

class SpaceSwitcher extends StatelessWidget {
  const SpaceSwitcher({
    required this.spaces,
    required this.currentId,
    required this.personalLabel,
    required this.onSelect,
    super.key,
  });
  final List<({String id, String name, Color accent, bool personal})> spaces;
  final String? currentId;
  final String personalLabel;
  final ValueChanged<String> onSelect;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final space in spaces)
        Semantics(
          selected: currentId == space.id,
          child: ListTile(
            minVerticalPadding: 12,
            title: SpaceHeading(name: space.name, accent: space.accent),
            subtitle: space.personal ? HandText(personalLabel) : null,
            trailing: currentId == space.id
                ? Text('✓', style: context.jiabu.type.body)
                : null,
            onTap: () => onSelect(space.id),
          ),
        ),
    ],
  );
}
