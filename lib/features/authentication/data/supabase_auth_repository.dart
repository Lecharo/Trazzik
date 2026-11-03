import 'package:supabase_flutter/supabase_flutter.dart';

/// Repositorio de autenticación con Supabase Auth.
class SupabaseAuthRepository {
  final SupabaseClient _client;

  SupabaseAuthRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
    String? userType,
  }) async {
    final meta = <String, dynamic>{};
    if (fullName != null) meta['full_name'] = fullName;
    if (userType != null) meta['user_type'] = userType;

    return await _client.auth.signUp(
      email: email,
      password: password,
      data: meta.isNotEmpty ? meta : null,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
