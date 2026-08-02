/// The vocabulary of signing in.
///
/// These types exist so that nothing above the data layer imports `firebase_auth`. Swapping the
/// identity provider is then a change to one gateway implementation rather than to every screen
/// that knows who the user is (Principle V).
library;

import 'package:meta/meta.dart';

/// The social providers offered. There is no password provider, and there is not meant to be
/// one: FR-011 requires account creation with no password, form, or verification email.
enum SocialProvider {
  google,
  facebook,
  apple;

  String get label => switch (this) {
        SocialProvider.google => 'Google',
        SocialProvider.facebook => 'Facebook',
        SocialProvider.apple => 'Apple',
      };
}

/// The signed-in user, as the app needs them: an identity and the two things shown on screen.
@immutable
class AuthUser {
  const AuthUser({required this.uid, this.displayName, this.avatarUrl});

  /// The Firebase UID — canonical identity everywhere, including on the backend.
  final String uid;
  final String? displayName;
  final String? avatarUrl;

  /// Up to two initials for the avatar fallback. Empty when there is no name to derive from.
  String get initials {
    final String name = displayName?.trim() ?? '';
    if (name.isEmpty) return '';
    final List<String> parts = name.split(RegExp(r'\s+')).where((String p) => p.isNotEmpty).toList();
    if (parts.length == 1) return parts.first.characters1;
    return '${parts.first.characters1}${parts.last.characters1}';
  }
}

extension on String {
  /// First character, uppercased. Guards against an empty segment.
  String get characters1 => isEmpty ? '' : substring(0, 1).toUpperCase();
}

/// The outcome of one authorisation.
///
/// [isNewUser] and [providerDisplayName] are the two fields that make sign-up a real flow rather
/// than a label on a button (research D13):
///
/// * [isNewUser] gates the first-run welcome (FR-080).
/// * [providerDisplayName] is the name the provider supplied *on this authorisation*. Apple
///   supplies it only on the very first one, so it is a now-or-never value (FR-081).
@immutable
class AuthResult {
  const AuthResult({
    required this.user,
    required this.isNewUser,
    this.providerDisplayName,
    this.displayNameWriteFailed = false,
  });

  final AuthUser user;
  final bool isNewUser;
  final String? providerDisplayName;

  /// True when the name was learned but could not be persisted — so a caller can offer a retry
  /// rather than leaving the account silently unnamed forever (Principle IV).
  final bool displayNameWriteFailed;

  AuthResult copyWith({bool? displayNameWriteFailed}) => AuthResult(
        user: user,
        isNewUser: isNewUser,
        providerDisplayName: providerDisplayName,
        displayNameWriteFailed: displayNameWriteFailed ?? this.displayNameWriteFailed,
      );
}
