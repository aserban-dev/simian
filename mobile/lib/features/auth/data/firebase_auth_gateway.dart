/// The Firebase implementation of the identity seam (T066).
///
/// This is the only file in the app that imports `firebase_auth`. All three providers go through
/// `signInWithProvider`, so there is no per-provider SDK and no per-provider flow to keep in
/// step — the difference between Google, Facebook and Apple is one argument.
library;

import 'package:firebase_auth/firebase_auth.dart';

import '../domain/auth_gateway.dart';
import '../domain/auth_models.dart';

class FirebaseAuthGateway implements AuthGateway {
  FirebaseAuthGateway(this._auth);

  final FirebaseAuth _auth;

  @override
  AuthUser? get currentUser => _toAuthUser(_auth.currentUser);

  @override
  Stream<AuthUser?> authStateChanges() => _auth.authStateChanges().map(_toAuthUser);

  @override
  Future<AuthResult> signIn(SocialProvider provider) async {
    final UserCredential credential = await _auth.signInWithProvider(_providerFor(provider));
    final AuthUser? user = _toAuthUser(credential.user);
    if (user == null) {
      // Firebase returning a credential with no user would mean the SDK contract broke.
      throw StateError('sign-in returned no user');
    }
    return AuthResult(
      user: user,
      // FR-080. Absent means "not new" rather than "unknown": showing a returning user the
      // first-run welcome is the more visible mistake of the two.
      isNewUser: credential.additionalUserInfo?.isNewUser ?? false,
      providerDisplayName: _nameFromAuthorisation(credential),
    );
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<String?> idToken({bool forceRefresh = false}) async =>
      _auth.currentUser?.getIdToken(forceRefresh);

  /// The name this *authorisation* carried, which is not the same as the name on the profile.
  ///
  /// FR-081 / research D13: Apple puts the user's full name in the authorisation response on the
  /// very first sign-in and never again, and it is not in the ID token — so the backend cannot
  /// discover it later. Reading it here, and only here, is the one chance there is.
  static String? _nameFromAuthorisation(UserCredential credential) {
    final Object? fromProfile = credential.additionalUserInfo?.profile?['name'];
    if (fromProfile is String && fromProfile.trim().isNotEmpty) return fromProfile;
    return credential.user?.displayName;
  }

  static AuthProvider _providerFor(SocialProvider provider) => switch (provider) {
        SocialProvider.google => GoogleAuthProvider(),
        SocialProvider.facebook => FacebookAuthProvider(),
        SocialProvider.apple => AppleAuthProvider(),
      };

  static AuthUser? _toAuthUser(User? user) => user == null
      ? null
      : AuthUser(uid: user.uid, displayName: user.displayName, avatarUrl: user.photoURL);
}
