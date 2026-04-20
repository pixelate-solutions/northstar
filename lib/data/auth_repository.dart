import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';

const authRedirectUrl = String.fromEnvironment(
  'SUPABASE_AUTH_REDIRECT_URL',
  defaultValue: 'com.northstar.northstar://login-callback',
);
const _accountServerUrl = String.fromEnvironment(
  'AGENT_SERVER_URL',
  defaultValue: 'https://northstar-agent.fly.dev',
);

class AuthRepository {
  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

  User? get currentUser => supabase.auth.currentUser;

  String? get currentUserId => currentUser?.id;

  Future<void> signInWithEmail(String email, String password) async {
    await supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUpWithEmail(
    String name,
    String email,
    String password,
  ) async {
    await supabase.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: authRedirectUrl,
      data: {'name': name, 'full_name': name},
    );
  }

  Future<void> signInWithGoogle() async {
    await supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: authRedirectUrl,
    );
  }

  Future<void> signInWithApple() async {
    await supabase.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: authRedirectUrl,
    );
  }

  Future<void> updateName(String name) async {
    await updateProfile(name: name);
  }

  Future<void> updateProfile({
    String? name,
    String? avatarUrl,
    Map<String, dynamic>? preferences,
  }) async {
    final metadata = Map<String, dynamic>.from(currentUser?.userMetadata ?? {});
    if (name != null) {
      metadata['name'] = name;
      metadata['full_name'] = name;
    }
    if (avatarUrl != null) {
      metadata['avatar_url'] = avatarUrl;
    }
    if (preferences != null) {
      final currentPreferences = Map<String, dynamic>.from(
        (metadata['preferences'] as Map?) ?? {},
      );
      metadata['preferences'] = {...currentPreferences, ...preferences};
    }
    await supabase.auth.updateUser(UserAttributes(data: metadata));
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  Future<void> sendPasswordReset(String email) async {
    await supabase.auth.resetPasswordForEmail(
      email,
      redirectTo: authRedirectUrl,
    );
  }

  Future<void> deleteAccount() async {
    final jwt = supabase.auth.currentSession?.accessToken;
    if (jwt == null) throw StateError('You must be signed in.');
    final response = await http.delete(
      Uri.parse('$_accountServerUrl/v1/account'),
      headers: {'Authorization': 'Bearer $jwt'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Could not delete account.';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        message = body['error'] as String? ?? message;
      } catch (_) {
        if (response.body.isNotEmpty) message = response.body;
      }
      throw StateError(message);
    }
    await signOut();
  }

  bool get isSignedIn => currentUser != null;
}
