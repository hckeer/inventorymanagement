import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/equipment/equipment_list_screen.dart';
import 'screens/equipment/equipment_detail_screen.dart';
import 'screens/equipment/equipment_form_screen.dart';
import 'screens/clients/client_list_screen.dart';
import 'screens/clients/client_detail_screen.dart';
import 'screens/clients/client_form_screen.dart';
import 'screens/rentals/rental_list_screen.dart';
import 'screens/rentals/rental_detail_screen.dart';
import 'screens/rentals/rental_form_screen.dart';
import 'screens/equipment/scanner_screen.dart';

// ---------------------------------------------------------------------------
// Router provider — Riverpod-aware so auth changes trigger redirects
// ---------------------------------------------------------------------------

final routerProvider = Provider<GoRouter>((ref) {
  // Listen to auth state so the router can rebuild on login/logout
  final authNotifier = _AuthNotifier(ref);

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final isAuthenticated =
          Supabase.instance.client.auth.currentSession != null;
      final isOnLogin = state.matchedLocation == '/login';

      if (!isAuthenticated && !isOnLogin) return '/login';
      if (isAuthenticated && isOnLogin) return '/dashboard';
      return null;
    },
    routes: [
      // ── Auth ──────────────────────────────────────────────────────────────
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),

      // ── Scanner ───────────────────────────────────────────────────────────
      GoRoute(
        path: '/scanner',
        builder: (context, state) => const ScannerScreen(),
      ),

      // ── Shell (persistent NavigationBar) ─────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => _AppShell(child: child),
        routes: [
          // Dashboard
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),

          // Equipment
          GoRoute(
            path: '/equipment',
            builder: (context, state) => const EquipmentListScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) =>
                    const EquipmentFormScreen(equipmentId: null),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) =>
                    EquipmentDetailScreen(id: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => EquipmentFormScreen(
                      equipmentId: state.pathParameters['id'],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Clients
          GoRoute(
            path: '/clients',
            builder: (context, state) => const ClientListScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) =>
                    const ClientFormScreen(clientId: null),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) =>
                    ClientDetailScreen(id: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => ClientFormScreen(
                      clientId: state.pathParameters['id'],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Rentals
          GoRoute(
            path: '/rentals',
            builder: (context, state) => const RentalListScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) =>
                    const RentalFormScreen(rentalId: null),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) =>
                    RentalDetailScreen(id: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => RentalFormScreen(
                      rentalId: state.pathParameters['id'],
                    ),
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

// ---------------------------------------------------------------------------
// AuthNotifier — ChangeNotifier that fires whenever auth state changes,
// giving GoRouter's refreshListenable a signal to re-evaluate redirects.
// ---------------------------------------------------------------------------

class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(this._ref) {
    _ref.listen<AsyncValue<AuthState>>(authStateProvider, (_, __) {
      notifyListeners();
    });
  }
  final Ref _ref;
}

// ---------------------------------------------------------------------------
// AppShell — persistent bottom NavigationBar wrapping the active screen
// ---------------------------------------------------------------------------

class _AppShell extends StatelessWidget {
  const _AppShell({required this.child});
  final Widget child;

  static const _tabs = [
    (icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'Dashboard', path: '/dashboard'),
    (icon: Icons.videocam_outlined, activeIcon: Icons.videocam_rounded, label: 'Equipment', path: '/equipment'),
    (icon: Icons.people_outline_rounded, activeIcon: Icons.people_rounded, label: 'Clients', path: '/clients'),
    (icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long_rounded, label: 'Rentals', path: '/rentals'),
  ];

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (int i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final idx = _selectedIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) => context.go(_tabs[i].path),
        destinations: _tabs.map((tab) => NavigationDestination(
          icon: Icon(tab.icon),
          selectedIcon: Icon(tab.activeIcon),
          label: tab.label,
        )).toList(),
      ),
    );
  }
}
