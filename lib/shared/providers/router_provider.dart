import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/app_prefs.dart';
import '../../core/services/auth_service.dart';
import '../../features/achievements/achievements_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/milestones/milestone_detail_screen.dart';
import '../../features/milestones/milestones_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/rewards/rewards_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/stats/stats_screen.dart';
import '../widgets/bottom_nav_shell.dart';
import 'auth_provider.dart';

/// Global key for navigator
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Router provider using go_router
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/home',
    debugLogDiagnostics: true,
    refreshListenable: ref.watch(authListenableProvider),
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final signedIn = AuthService.currentUser != null;
      // Login is the strictest gate.
      if (!signedIn) {
        return loc == '/login' ? null : '/login';
      }
      // Once signed in, kick off the onboarding gate.
      final done = AppPrefs.isOnboardingCompleteSync;
      if (!done && loc != '/onboarding') return '/onboarding';
      if (done && (loc == '/onboarding' || loc == '/login')) {
        return '/home';
      }
      return null;
    },
    routes: [
      // Login — top-level, outside the shell
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),

      // Onboarding — top-level, outside the shell (no bottom nav)
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      // Settings — top-level, outside the shell (no bottom nav, has back arrow)
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return BottomNavShell(navigationShell: navigationShell);
        },
        branches: [
          // Home Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                name: 'home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),

          // Projects Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/milestones',
                name: 'milestones',
                builder: (context, state) => const MilestonesScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    name: 'milestoneDetail',
                    builder: (context, state) => MilestoneDetailScreen(
                      milestoneId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Rewards Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/rewards',
                name: 'rewards',
                builder: (context, state) => const RewardsScreen(),
              ),
            ],
          ),

          // Stats Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/stats',
                name: 'stats',
                builder: (context, state) => const StatsScreen(),
                routes: [
                  GoRoute(
                    path: 'achievements',
                    name: 'achievements',
                    builder: (context, state) => const AchievementsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
