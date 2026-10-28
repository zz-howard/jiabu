import 'package:go_router/go_router.dart';
import 'package:jiabu/features/auth/view/auth_shell.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

@Riverpod(dependencies: [])
GoRouter router(Ref ref) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const AuthShell()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}
