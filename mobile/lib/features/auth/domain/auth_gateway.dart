/// The identity seam (Principle V).
///
/// One interface for "who is signed in, and how do they sign in or out". The Firebase
/// implementation lives in `data/firebase_auth_gateway.dart`; tests substitute a fake, which is
/// what lets the sign-up rules be tested without a Firebase project.
library;

import 'auth_models.dart';

abstract class AuthGateway {
  /// The signed-in user, or null. Read synchronously because the SDK caches the session
  /// locally — a relaunch is signed in before any network call (FR-015).
  AuthUser? get currentUser;

  Stream<AuthUser?> authStateChanges();

  /// Runs the provider authorisation. Both sign-up and sign-in are this same call; which one
  /// happened is reported by [AuthResult.isNewUser] (FR-080).
  Future<AuthResult> signIn(SocialProvider provider);

  Future<void> signOut();

  /// The current ID token, or null when signed out.
  ///
  /// [forceRefresh] is what makes FR-015 possible: on a 401 the client asks for a genuinely new
  /// token rather than the cached one it just had rejected.
  Future<String?> idToken({bool forceRefresh = false});
}
