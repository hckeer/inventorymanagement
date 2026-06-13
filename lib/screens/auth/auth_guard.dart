import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';

/// GoRouter redirect helper.
/// Call [AuthGuard.redirect] from a route or shell-route `redirect` callback.
class AuthGuard {
  const AuthGuard._();

  /// Returns `/login` when the user is unauthenticated, otherwise returns null
  /// (meaning: proceed to the requested route).
  static String? redirect(WidgetRef ref, GoRouterState state) {
    final authAsync = ref.read(authStateProvider);

    // While loading we allow the navigation to proceed — the router will
    // re-evaluate once the stream emits.
    return authAsync.when(
      data: (authState) {
        final isSignedIn =
            authState.event != AuthChangeEvent.signedOut &&
            authState.session != null;
        if (!isSignedIn && state.matchedLocation != '/login') {
          return '/login';
        }
        // If already signed in and on /login, go to dashboard.
        if (isSignedIn && state.matchedLocation == '/login') {
          return '/dashboard';
        }
        return null;
      },
      loading: () => null,
      error: (_, __) => '/login',
    );
  }
}
