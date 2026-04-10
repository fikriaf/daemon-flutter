import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../screens/root_screen.dart';
import '../screens/discover_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/library_screen.dart';
import '../screens/spaces_screen.dart';
import '../screens/cyclops_screen.dart';
import '../screens/obscura_screen.dart';
import '../screens/world_radar_screen.dart';
import '../screens/sandbox_screen.dart';
import '../screens/sandbox_connectors_screen.dart';
import '../screens/sandbox_files_screen.dart';
import '../screens/sandbox_live_screen.dart';
import '../screens/finance_screen.dart';
import '../screens/audit_screen.dart';
import '../screens/login_screen.dart';
import '../screens/verify_email_screen.dart';
import '../services/agent_service.dart';

/// Shared navigator key — used by main.dart to show modals from deep links.
final routerNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: routerNavigatorKey,
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => RootScreen(
          initialSession: state.extra is ChatSession
              ? state.extra as ChatSession
              : null,
        ),
      ),
      GoRoute(
        path: '/discover',
        builder: (context, state) => const DiscoverScreen(),
      ),
      GoRoute(
        path: '/library',
        builder: (context, state) => const LibraryScreen(),
      ),
      GoRoute(
        path: '/spaces',
        builder: (context, state) => const SpacesScreen(),
      ),
      GoRoute(
        path: '/spaces/cyclops',
        builder: (context, state) => const CyclopsScreen(),
      ),
      GoRoute(
        path: '/spaces/obscura',
        builder: (context, state) => const ObscuraScreen(),
      ),
      GoRoute(
        path: '/spaces/worldmonitor',
        builder: (context, state) => const WorldRadarScreen(),
      ),
      GoRoute(
        path: '/worldmonitor',
        builder: (context, state) => WorldRadarScreen(
          initialSession: state.extra is ChatSession
              ? state.extra as ChatSession
              : null,
        ),
      ),
      GoRoute(
        path: '/sandbox',
        builder: (context, state) => const SandboxScreen(),
      ),
      GoRoute(
        path: '/sandbox/connectors',
        builder: (context, state) => const SandboxConnectorsScreen(),
      ),
      GoRoute(
        path: '/sandbox/files',
        builder: (context, state) => const SandboxFilesScreen(),
      ),
      GoRoute(
        path: '/sandbox/live',
        builder: (context, state) => const SandboxLiveScreen(),
      ),
      GoRoute(
        path: '/finance',
        builder: (context, state) => const FinanceScreen(),
      ),
      GoRoute(path: '/audit', builder: (context, state) => const AuditScreen()),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      // Email verification deep link: daemonai://verify-email?token=xxx
      GoRoute(
        path: '/verify-email',
        builder: (context, state) =>
            VerifyEmailScreen(token: state.uri.queryParameters['token']),
      ),
      // Already verified via browser redirect: daemonai://verified?email=xxx
      GoRoute(
        path: '/verified',
        builder: (context, state) =>
            VerifyEmailScreen(email: state.uri.queryParameters['email']),
      ),
    ],
  );
});
