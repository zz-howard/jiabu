import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jiabu/shared/c4/c4_view_model.dart';
import 'package:jiabu_design/jiabu_design.dart';

class C4Field extends ConsumerWidget {
  const C4Field({
    required this.id,
    required this.field,
    required this.label,
    this.initial = '',
    this.obscure = false,
    this.keyboard,
    super.key,
  });
  final String id;
  final String field;
  final String label;
  final String initial;
  final bool obscure;
  final TextInputType? keyboard;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: EdgeInsets.only(bottom: context.jiabu.decor.cardGap),
    child: TextFormField(
      key: ValueKey('$id:$field'),
      initialValue: initial,
      readOnly:
          ref.watch(c4ViewModelProvider(id)).values['_frozen'] == true ||
          ref.watch(c4ViewModelProvider(id)).busy,
      obscureText: obscure,
      enableSuggestions: !obscure,
      autocorrect: !obscure,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label),
      onChanged: (value) =>
          ref.read(c4ViewModelProvider(id).notifier).patch(field, value),
    ),
  );
}
