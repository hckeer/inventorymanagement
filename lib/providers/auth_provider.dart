import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/auth_repository.dart';
import '../models/user_profile.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(),
);

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).watchAuthState();
});

final currentUserProfileProvider = FutureProvider<UserProfile?>((ref) {
  // Re-run whenever the auth state changes.
  ref.watch(authStateProvider);
  return ref.read(authRepositoryProvider).getCurrentUserProfile();
});
