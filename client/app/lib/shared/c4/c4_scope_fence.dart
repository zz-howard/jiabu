import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jiabu/app/ledger_providers.dart';

/// Closes the whole modal on partition/space changes without requiring ledger
/// module access. The body disappears synchronously before route removal.
class C4ScopeFence extends ConsumerStatefulWidget {
  const C4ScopeFence({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<C4ScopeFence> createState() => _C4ScopeFenceState();
}

class _C4ScopeFenceState extends ConsumerState<C4ScopeFence> {
  LedgerPresentationSession? _owner;
  bool _closed = false;
  @override
  Widget build(BuildContext context) {
    final session = ref.watch(ledgerPresentationSessionProvider);
    _owner ??= session;
    if (_closed || session == null || session != _owner) {
      if (!_closed) {
        _closed = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          final route = ModalRoute.of(context);
          if (route != null && route.isActive) {
            Navigator.of(context).removeRoute(route);
          }
        });
      }
      return const SizedBox.shrink();
    }
    return widget.child;
  }
}
