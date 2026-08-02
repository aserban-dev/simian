/// Sign-in and sign-out orchestration (T164, T068, T165's gating input).
///
/// The repository is the seam where the three requirements that are easy to get wrong meet:
/// capture the provider's name at sign-up (FR-081), report whether the account is new (FR-080),
/// and purge user-scoped caches on the way out (FR-016).
library;

import 'package:dupermarket/core/errors/app_failure.dart';
import 'package:dupermarket/core/network/api_client.dart';
import 'package:dupermarket/features/auth/data/auth_repository.dart';
import 'package:dupermarket/features/auth/domain/auth_gateway.dart';
import 'package:dupermarket/features/auth/domain/auth_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// An in-memory gateway. The real one talks to Firebase; this one answers from a script, so the
/// repository's rules are testable without a Firebase project.
class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({this.result, this.throwOnSignIn});

  AuthResult? result;
  Object? throwOnSignIn;
  int signOutCalls = 0;
  final List<bool> idTokenForceFlags = <bool>[];

  @override
  AuthUser? currentUser;

  @override
  Stream<AuthUser?> authStateChanges() => Stream<AuthUser?>.value(currentUser);

  @override
  Future<AuthResult> signIn(SocialProvider provider) async {
    // The fake replays whatever the caller scripted, including the ApiException the real
    // gateway would surface.
    // ignore: only_throw_errors
    if (throwOnSignIn != null) throw throwOnSignIn!;
    final AuthResult outcome = result!;
    currentUser = outcome.user;
    return outcome;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    currentUser = null;
  }

  @override
  Future<String?> idToken({bool forceRefresh = false}) async {
    idTokenForceFlags.add(forceRefresh);
    return currentUser == null ? null : 'token-for-${currentUser!.uid}';
  }
}

class RecordingProfileApi implements ProfileApi {
  RecordingProfileApi({this.failWith});

  final Object? failWith;
  final List<String> namesWritten = <String>[];

  @override
  Future<void> updateDisplayName(String displayName) async {
    // ignore: only_throw_errors — see FakeAuthGateway.signIn.
    if (failWith != null) throw failWith!;
    namesWritten.add(displayName);
  }
}

AuthResult _result({
  String? providerName,
  bool isNewUser = true,
  String? profileName,
}) =>
    AuthResult(
      user: AuthUser(uid: 'uid-1', displayName: profileName),
      isNewUser: isNewUser,
      providerDisplayName: providerName,
    );

({AuthRepository repo, FakeAuthGateway gateway, RecordingProfileApi api, List<int> purges})
    _build({
  AuthResult? result,
  Object? profileApiFailure,
  Object? signInFailure,
}) {
  final gateway = FakeAuthGateway(result: result, throwOnSignIn: signInFailure);
  final api = RecordingProfileApi(failWith: profileApiFailure);
  final purges = <int>[];
  final repo = AuthRepository(
    gateway: gateway,
    profileApi: api,
    clearUserScopedCache: () async => purges.add(1),
  );
  return (repo: repo, gateway: gateway, api: api, purges: purges);
}

void main() {
  group('sign-up captures the provider name (T164, FR-081)', () {
    test('a name returned on first authorisation is written to the profile immediately', () async {
      // Apple hands the name over exactly once. If it is not written here, it is gone.
      final b = _build(result: _result(providerName: 'Sam Shopper'));

      await b.repo.signIn(SocialProvider.apple);

      expect(b.api.namesWritten, <String>['Sam Shopper']);
    });

    test('a returning sign-in writes nothing, so it cannot clobber the stored name', () async {
      final b = _build(result: _result(providerName: null, isNewUser: false));

      await b.repo.signIn(SocialProvider.apple);

      expect(b.api.namesWritten, isEmpty);
    });

    test('a returning sign-in that does carry a name still writes nothing', () async {
      // The backend refreshes from the token on every call; a second write here would be a
      // second source of truth for the same field.
      final b = _build(result: _result(providerName: 'Sam Shopper', isNewUser: false));

      await b.repo.signIn(SocialProvider.google);

      expect(b.api.namesWritten, isEmpty);
    });

    test('a sign-up with no name from the provider writes nothing', () async {
      final b = _build(result: _result(providerName: null));

      await b.repo.signIn(SocialProvider.apple);

      expect(b.api.namesWritten, isEmpty);
    });

    test('an empty name is not written', () async {
      final b = _build(result: _result(providerName: ''));

      await b.repo.signIn(SocialProvider.apple);

      expect(b.api.namesWritten, isEmpty);
    });

    test('the credential profile name is used when the provider response carries none', () async {
      // Google and Facebook populate the Firebase user profile directly.
      final b = _build(result: _result(providerName: null, profileName: 'Sam From Google'));

      await b.repo.signIn(SocialProvider.google);

      expect(b.api.namesWritten, <String>['Sam From Google']);
    });

    test('a failed profile write does not fail the sign-in (Principle IV)', () async {
      final b = _build(
        result: _result(providerName: 'Sam Shopper'),
        profileApiFailure: const ApiException(NoConnectivity()),
      );

      final AuthResult outcome = await b.repo.signIn(SocialProvider.apple);

      expect(outcome.isNewUser, isTrue, reason: 'the user is signed in; the name write is not');
    });

    test('a failed name write is reported so the caller can retry it', () async {
      final b = _build(
        result: _result(providerName: 'Sam Shopper'),
        profileApiFailure: const ApiException(NoConnectivity()),
      );

      final AuthResult outcome = await b.repo.signIn(SocialProvider.apple);

      expect(outcome.displayNameWriteFailed, isTrue);
    });

    test('a successful sign-up reports no write failure', () async {
      final b = _build(result: _result(providerName: 'Sam Shopper'));

      final AuthResult outcome = await b.repo.signIn(SocialProvider.apple);

      expect(outcome.displayNameWriteFailed, isFalse);
    });
  });

  group('first-run gating (T165, FR-080)', () {
    test('a first authorisation reports isNewUser', () async {
      final b = _build(result: _result(isNewUser: true));

      expect((await b.repo.signIn(SocialProvider.google)).isNewUser, isTrue);
    });

    test('authorising again with the same provider does not report a new account', () async {
      final b = _build(result: _result(isNewUser: false));

      expect((await b.repo.signIn(SocialProvider.google)).isNewUser, isFalse);
    });
  });

  group('sign-out (T068, FR-016)', () {
    test('user-scoped caches are purged', () async {
      final b = _build(result: _result());
      await b.repo.signIn(SocialProvider.google);

      await b.repo.signOut();

      expect(b.purges, hasLength(1));
    });

    test('the credential is dropped', () async {
      final b = _build(result: _result());
      await b.repo.signIn(SocialProvider.google);

      await b.repo.signOut();

      expect(b.gateway.signOutCalls, 1);
      expect(b.gateway.currentUser, isNull);
    });

    test('the cache is purged even when the provider sign-out throws', () async {
      // Otherwise a provider hiccup leaves the previous user's data on a shared device.
      final gateway = _ThrowingSignOutGateway();
      final repo = AuthRepository(
        gateway: gateway,
        profileApi: RecordingProfileApi(),
        clearUserScopedCache: () async => gateway.purged = true,
      );

      await expectLater(repo.signOut(), throwsA(isA<StateError>()));
      expect(gateway.purged, isTrue);
    });
  });
}

class _ThrowingSignOutGateway extends FakeAuthGateway {
  bool purged = false;

  @override
  Future<void> signOut() async => throw StateError('provider unreachable');
}
