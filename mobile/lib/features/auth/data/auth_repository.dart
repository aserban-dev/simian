/// Sign-in and sign-out orchestration (T164, T068).
///
/// The gateway knows how to authorise; this knows what has to happen around it. Two rules live
/// here, and both are the kind that silently stop working if they are left to a screen:
///
/// * **Capture the name at sign-up** (FR-081). Apple supplies it once, and the backend never
///   sees it — it is not in the ID token — so the client has to write it, immediately.
/// * **Purge user-scoped caches at sign-out** (FR-016), including when the provider misbehaves.
library;

import '../../../core/network/api_client.dart';
import '../domain/auth_gateway.dart';
import '../domain/auth_models.dart';

/// The profile half of the API, narrowed to what signing in needs.
abstract class ProfileApi {
  Future<void> updateDisplayName(String displayName);
}

class HttpProfileApi implements ProfileApi {
  HttpProfileApi(this._client);

  final ApiClient _client;

  @override
  Future<void> updateDisplayName(String displayName) async {
    // Null and empty are no-ops server-side (FR-081); only a real name is ever sent.
    await _client.patchJson('/me', body: <String, dynamic>{'display_name': displayName});
  }
}

class AuthRepository {
  AuthRepository({
    required AuthGateway gateway,
    required ProfileApi profileApi,
    required Future<void> Function() clearUserScopedCache,
  })  : _gateway = gateway,
        _profileApi = profileApi,
        _clearUserScopedCache = clearUserScopedCache;

  final AuthGateway _gateway;
  final ProfileApi _profileApi;
  final Future<void> Function() _clearUserScopedCache;

  AuthUser? get currentUser => _gateway.currentUser;

  Stream<AuthUser?> authStateChanges() => _gateway.authStateChanges();

  /// Authorises with [provider], and on the sign-up path persists the name it supplied.
  ///
  /// The write is deliberately limited to first authorisation. On every later sign-in the
  /// backend refreshes the profile from the token itself, so writing again here would give the
  /// same field two sources of truth — and on Apple the client's would be the empty one.
  Future<AuthResult> signIn(SocialProvider provider) async {
    final AuthResult result = await _gateway.signIn(provider);
    if (!result.isNewUser) return result;

    final String name = _nameToPersist(result);
    if (name.isEmpty) return result;

    try {
      await _profileApi.updateDisplayName(name);
    } on Object {
      // Sign-in has already succeeded; failing it now over a profile field would strand a user
      // who is, in fact, signed in (Principle IV). Reported instead, so the caller can retry.
      return result.copyWith(displayNameWriteFailed: true);
    }
    return result;
  }

  /// Signs out and clears every user-scoped cache (FR-016).
  ///
  /// The purge is in a `finally` on purpose: if the provider call fails and the purge were
  /// skipped, the previous user's data would stay readable on a shared device — the exact
  /// outcome the requirement exists to prevent.
  Future<void> signOut() async {
    try {
      await _gateway.signOut();
    } finally {
      await _clearUserScopedCache();
    }
  }

  /// The provider's name for this authorisation, falling back to the credential's profile.
  ///
  /// Apple delivers it in the authorisation response; Google and Facebook populate the user
  /// profile directly. Either way it is trimmed, and an empty result means "nothing to write".
  static String _nameToPersist(AuthResult result) {
    final String fromAuthorisation = result.providerDisplayName?.trim() ?? '';
    if (fromAuthorisation.isNotEmpty) return fromAuthorisation;
    return result.user.displayName?.trim() ?? '';
  }
}
