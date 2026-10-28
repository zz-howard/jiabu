import 'package:jiabu/domain/entity_ref.dart';
import 'package:jiabu/domain/required_value.dart';

/// Shared by ordinary writes and conflict replay. Only newly added attachments
/// need a local upload receipt; retained server attachments may be cacheless.
Set<String> toolDependencies(
  String tool,
  Map<String, Object?> args, {
  Map<String, Object?> previous = const {},
}) {
  if (tool == 'set_allocation_plan') {
    return {EntityRef('account', requireValue<String>(args['account_id'])).key};
  }
  final refundOf = tool == 'create_record'
      ? args['refund_of_id']
      : previous['refund_of_id'];
  final refundDependencies = <String>{
    if (refundOf is String) EntityRef('record', refundOf).key,
  };
  if (tool == 'restore_record' || tool == 'void_record') {
    return refundDependencies;
  }
  if (tool != 'create_record' && tool != 'update_record') {
    return {};
  }
  final values = tool == 'update_record'
      ? requireValue<Map<String, Object?>>(args['changes'])
      : args;
  final retained = tool == 'update_record'
      ? previous['attachments'] as List<Object?>? ?? const <Object?>[]
      : const <Object?>[];
  return {
    ...refundDependencies,
    for (final field in [
      'account_id',
      'to_account_id',
      'purpose_id',
      'to_purpose_id',
    ])
      if (values[field] case final String id) EntityRef('account', id).key,
    for (final tag in (values['tag_ids'] as List<Object?>? ?? const []))
      EntityRef('tag', tag as String).key,
    for (final hash in (values['attachments'] as List<Object?>? ?? const []))
      if (!retained.contains(hash)) EntityRef.blob('ledger', hash as String),
  };
}

/// An expense void follows refund void acknowledgements, even when the refunds
/// already look voided locally. Ordinary record refs use C2's FIFO scheduler.
Set<String> refundVoidDependencies(Iterable<String> refundIds) => {
  for (final id in refundIds) EntityRef('record', id).key,
};
