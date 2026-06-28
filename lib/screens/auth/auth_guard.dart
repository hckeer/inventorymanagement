import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';

/// GoRouter redirect helper.
class AuthGuard {
  const AuthGuard._();

  static String? redirect(WidgetRef ref, GoRouterState state) {
    final authAsync = ref.read(authStateProvider);

    return authAsync.when(
      data: (isSignedIn) {
        if (!isSignedIn && state.matchedLocation != '/login') {
          return '/login';
        }
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
