import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../data/auth_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return AppSupabase.client;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

/// Emits the Supabase auth state (signed in / signed out).
final authStateProvider = StreamProvider<AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return Stream<AuthState>.multi((controller) {
    controller.add(
      AuthState(AuthChangeEvent.initialSession, repository.client.auth.currentSession),
    );
    final subscription = repository.onAuthStateChange.listen(controller.add);
    controller.onCancel = subscription.cancel;
  });
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).value?.session?.user;
});
