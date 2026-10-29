import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jiabu/app/c4_providers.dart';
import 'package:jiabu/app/providers.dart';
import 'package:jiabu/domain/app_lock.dart';
import 'package:jiabu/features/lock/view/unlock_screen.dart';
import 'package:jiabu_design/jiabu_design.dart';

class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> {
  AppLifecycleListener? _lifecycle;
  @override
  void initState() {
    super.initState();
    final lock = ref.read(appRuntimeProvider).lock;
    _lifecycle = AppLifecycleListener(
      onInactive: lock.background,
      onPause: () => lock.background(paused: true),
      onResume: lock.foreground,
    );
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(lockEventsProvider);
    final runtime = ref.watch(appRuntimeProvider);
    final lock = runtime.lock;
    // The C2 restricted-password shell renders no business data. Let it finish
    // the mandatory password change before asking for the app credential.
    if (runtime.auth.current?.passwordChangeRequired == true &&
        ref.watch(restrictedAuthenticationReadyProvider)) {
      return widget.child;
    }
    if (lock.phase == LockPhase.loading || lock.phase == LockPhase.covered) {
      return const Material(
        child: PaperBackground(
          child: Center(child: JiabuLogoSealPlaceholder()),
        ),
      );
    }
    if (lock.visible) {
      return const Material(child: UnlockScreen());
    }
    return widget.child;
  }
}
