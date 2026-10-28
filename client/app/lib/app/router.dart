import 'package:go_router/go_router.dart';
import 'package:jiabu/app/main_shell.dart';
import 'package:jiabu/features/auth/view/auth_shell.dart';
import 'package:jiabu/features/chat/view/chat_screen.dart';
import 'package:jiabu/features/history/view/history_screen.dart';
import 'package:jiabu/features/overview/view/overview_screen.dart';
import 'package:jiabu/features/settings/view/settings_screen.dart';
import 'package:jiabu/shared/ledger/ledger_pages.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

@Riverpod(dependencies: [])
GoRouter router(Ref ref) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', redirect: (context, state) => '/chat'),
      ShellRoute(
        builder: (context, state, child) => AuthShell(
          signedInChild: MainShell(path: state.uri.path, child: child),
        ),
        routes: [
          GoRoute(
            path: '/chat',
            builder: (context, state) => const ChatScreen(),
          ),
          GoRoute(
            path: '/overview',
            builder: (context, state) => const OverviewScreen(),
          ),
          GoRoute(
            path: '/history',
            builder: (context, state) => const HistoryScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
            routes: [
              GoRoute(
                path: 'accounts',
                builder: (context, state) =>
                    const LedgerRoutePage(page: 'accounts'),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}
