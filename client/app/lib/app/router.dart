import 'package:go_router/go_router.dart';
import 'package:jiabu/app/main_shell.dart';
import 'package:jiabu/features/auth/view/auth_shell.dart';
import 'package:jiabu/features/chat/view/chat_screen.dart';
import 'package:jiabu/features/history/view/history_screen.dart';
import 'package:jiabu/features/lock/view/lock_settings_screen.dart';
import 'package:jiabu/features/overview/view/overview_screen.dart';
import 'package:jiabu/features/settings/api_keys/api_keys_screen.dart';
import 'package:jiabu/features/settings/view/settings_screen.dart';
import 'package:jiabu/features/spaces/view/spaces_screen.dart';
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
            path: '/invitations',
            builder: (context, state) => const SpacesScreen(page: 'received'),
          ),
          for (final page in ['settings', 'members', 'invitations'])
            GoRoute(
              path: '/spaces/:spaceId/$page',
              builder: (context, state) => SpacesScreen(
                page: page,
                spaceId: state.pathParameters['spaceId'],
              ),
            ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
            routes: [
              for (final page in ['account', 'language', 'about'])
                GoRoute(
                  path: page,
                  builder: (context, state) => SettingsScreen(page: page),
                ),
              GoRoute(
                path: 'account/password',
                builder: (context, state) =>
                    const SettingsScreen(page: 'password'),
              ),
              GoRoute(
                path: 'api-keys',
                builder: (context, state) => const ApiKeysScreen(),
              ),
              GoRoute(
                path: 'app-lock',
                builder: (context, state) => const LockSettingsScreen(),
              ),
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
