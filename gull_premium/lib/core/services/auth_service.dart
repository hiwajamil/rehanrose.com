import 'package:firebase_auth/firebase_auth.dart' as fa;

import '../../data/repositories/auth_repository.dart';

/// Customer-facing auth service. Handles sign-in (Google, email/password)
/// and sign-out. Use [authStateProvider] to react to auth state changes.
class AuthService {
  AuthService(this._repo);

  final AuthRepository _repo;

  /// Sign in with Google. On success, ensures a user document exists in
  /// Firestore [users] with role 'customer' if new.
  Future<fa.UserCredential> signInWithGoogle() => _repo.signInWithGoogle();

  /// Sign in with email and password.
  Future<fa.UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) =>
      _repo.signInWithEmailAndPassword(email: email, password: password);

  /// Create account with email and password. Ensures a user document exists in
  /// Firestore with role 'customer' for new users.
  Future<fa.UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final cred = await _repo.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (cred.user != null) {
      await _repo.ensureCustomerUserDocIfNeeded(cred.user!);
    }
    return cred;
  }

  /// Sign out (Firebase and Google).
  Future<void> signOut() => _repo.signOut();
}
