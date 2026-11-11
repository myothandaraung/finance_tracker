import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/supabase_repository.dart';
import '../../../core/errors/app_exception.dart';

/// Authentication and profile operations.
class AuthRepository extends SupabaseRepository {
  const AuthRepository(super.client);

  Stream<AuthState> get onAuthStateChange => client.auth.onAuthStateChange;

  User? get currentUser => client.auth.currentUser;

  Future<void> signIn({required String email, required String password}) async {
    try {
      await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } catch (error) {
      throw AppException.fromSupabase(error);
    }
  }

  /// Creates the account. Returns `true` when the session is active straight
  /// away (development projects have email confirmation disabled) and `false`
  /// when the user still has to confirm the address.
  Future<bool> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final response = await client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          if (displayName != null && displayName.trim().isNotEmpty)
            'display_name': displayName.trim(),
        },
      );
      return response.session != null;
    } catch (error) {
      throw AppException.fromSupabase(error);
    }
  }

  Future<void> signOut() async {
    try {
      await client.auth.signOut();
    } catch (error) {
      throw AppException.fromSupabase(error);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await client.auth.resetPasswordForEmail(email.trim());
    } catch (error) {
      throw AppException.fromSupabase(error);
    }
  }

  /// Updates the display name of the signed in user.
  Future<void> updateProfile({String? displayName, String? phone}) async {
    await callRpc(
      'rpc_update_profile',
      params: {'p_display_name': displayName, 'p_phone': phone},
    );
  }
}
