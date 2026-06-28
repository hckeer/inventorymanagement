import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/auth_repository.dart';
import '../models/user_profile.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(),
);

/// True when an MCP access token exists and /auth/me succeeds.
final authSessionProvider = FutureProvider<bool>((ref) async {
  return ref.read(authRepositoryProvider).hasSession();
});

final currentUserProfileProvider = FutureProvider<UserProfile?>((ref) {
  ref.watch(authSessionProvider);
  return ref.read(authRepositoryProvider).getCurrentUserProfile();
});

/// Increment to force auth/session refresh after login or logout.
final authRevisionProvider = StateProvider<int>((ref) => 0);

final authStateProvider = FutureProvider<bool>((ref) {
  ref.watch(authRevisionProvider);
  return ref.read(authRepositoryProvider).hasSession();
});
