import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/auth_repository.dart';
import '../models/user_profile.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(),
);

/// True when an MCP access token exists and /auth/me succeeds.
final authSessionProvider = FutureProvider<bool>((ref) async {
  ref.watch(authRevisionProvider);
  return ref.read(authRepositoryProvider).hasSession();
});

final currentUserProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final isAuthenticated = await ref.watch(authStateProvider.future);
  if (!isAuthenticated) return null;
  return ref.read(authRepositoryProvider).getCurrentUserProfile();
});

/// Increment to force auth/session refresh after login or logout.
final authRevisionProvider = StateProvider<int>((ref) => 0);

final authStateProvider = FutureProvider<bool>((ref) {
  return ref.watch(authSessionProvider.future);
});
