import 'package:flutter/material.dart';
import 'package:jiabu_design/src/theme_context.dart';

class PinPad extends StatelessWidget {
  const PinPad({
    required this.length,
    required this.onDigit,
    required this.onDelete,
    required this.deleteLabel,
    this.enabled = true,
    super.key,
  });
  final int length;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final String deleteLabel;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      ExcludeSemantics(
        child: Text(
          List<String>.filled(length, '●').join(),
          style: context.jiabu.type.sectionTitle,
        ),
      ),
      for (final row in const ['123', '456', '789', '0'])
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final digit in row.split(''))
              Padding(
                padding: const EdgeInsets.all(4),
                child: SizedBox.square(
                  dimension: 64,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: enabled ? () => onDigit(digit) : null,
                    child: Text(digit, style: context.jiabu.type.pinDigit),
                  ),
                ),
              ),
          ],
        ),
      TextButton(
        onPressed: enabled ? onDelete : null,
        child: Text(deleteLabel),
      ),
    ],
  );
}
