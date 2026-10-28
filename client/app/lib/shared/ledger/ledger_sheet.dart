import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jiabu/app/ledger_providers.dart';
import 'package:jiabu/shared/ledger/ledger_view_model.dart';
import 'package:jiabu/shared/ledger/record_details.dart';
import 'package:jiabu_design/jiabu_design.dart';

/// One access boundary for the ENTIRE modal, including its fixed footer.
abstract final class LedgerSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required String spaceId,
    required WidgetBuilder builder,
    WidgetBuilder? footerBuilder,
    bool requireWrite = false,
  }) => PaperSheet.show<T>(
    context: context,
    builder: builder,
    footerBuilder: footerBuilder,
    wrapperBuilder: (_, child) => LedgerSheetFence(
      spaceId: spaceId,
      requireWrite: requireWrite,
      child: child,
    ),
  );
}

class LedgerSheetFence extends ConsumerStatefulWidget {
  const LedgerSheetFence({
    required this.spaceId,
    required this.child,
    this.requireWrite = false,
    super.key,
  });
  final String spaceId;
  final bool requireWrite;
  final Widget child;

  @override
  ConsumerState<LedgerSheetFence> createState() => _LedgerSheetFenceState();
}

class _LedgerSheetFenceState extends ConsumerState<LedgerSheetFence> {
  LedgerPresentationSession? _owner;
  (String, int, int)? _membership;
  bool _revoked = false;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(ledgerPresentationSessionProvider);
    final snapshot = ref
        .watch(ledgerViewModelProvider(widget.spaceId))
        .snapshot;
    final space = snapshot?.space;
    final memberId = space?.text('member_id') ?? '';
    final member = snapshot?.find(snapshot.members, memberId);
    final level = (space?.data['modules'] as Map<String, Object?>?)?['ledger'];
    final membership = (
      memberId,
      space?.number('join_epoch') ?? 0,
      space?.number('local_generation') ?? 0,
    );
    if (!_revoked &&
        snapshot == null &&
        _membership == null &&
        session != null &&
        session.spaceId == widget.spaceId &&
        (_owner == null || _owner == session)) {
      _owner ??= session;
      return const SizedBox.shrink();
    }
    final valid =
        session != null &&
        session.spaceId == widget.spaceId &&
        snapshot != null &&
        space?.id == widget.spaceId &&
        memberId.isNotEmpty &&
        (member == null || member.text('status') == 'active') &&
        member?.data['left_at'] == null &&
        const ['read', 'write', 'manage'].contains(level) &&
        (!widget.requireWrite || snapshot.writable) &&
        (_owner == null || _owner == session) &&
        (_membership == null || _membership == membership);
    if (_revoked || !valid) {
      if (!_revoked) {
        _revoked = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          ref
            ..invalidate(ledgerFormViewModelProvider)
            ..invalidate(recordImageProvider);
          final route = ModalRoute.of(context);
          if (route != null && route.isActive) {
            Navigator.of(context).removeRoute(route);
          }
        });
      }
      // Remove cached bytes and text immediately, before the route is removed.
      return const SizedBox.shrink();
    }
    _owner ??= session;
    _membership ??= membership;
    return widget.child;
  }
}
