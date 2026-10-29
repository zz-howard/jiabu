import 'package:flutter/material.dart';
import 'package:jiabu_design/src/theme_context.dart';

class SpaceAccentPicker extends StatelessWidget {
  const SpaceAccentPicker({
    required this.value,
    required this.onChanged,
    required this.label,
    this.names = const {},
    super.key,
  });
  final String value;
  final ValueChanged<String>? onChanged;
  final String label;
  final Map<String, String> names;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 4,
    children: [
      for (final entry in context.jiabu.colors.spaceAccents.entries)
        Semantics(
          label: '$label ${names[entry.key] ?? entry.key}',
          selected: entry.key == value,
          button: true,
          child: InkWell(
            onTap: onChanged == null ? null : () => onChanged?.call(entry.key),
            child: SizedBox.square(
              dimension: 48,
              child: Center(
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: entry.value,
                    border: Border.all(
                      color: context.jiabu.colors.onPrimary,
                      width: entry.key == value ? 3 : 1,
                    ),
                  ),
                  child: entry.key == value
                      ? Center(
                          child: Text(
                            '✓',
                            style: TextStyle(
                              color: context.jiabu.colors.onPrimary,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
