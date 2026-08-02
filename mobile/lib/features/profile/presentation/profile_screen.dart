/// The profile screen (T069).
///
/// Shows the display name and avatar the provider supplied, and offers sign-out. Both fields are
/// optional in practice — Apple's "Hide My Email" and a declined name leave an account with
/// neither — so every widget here has a defined appearance when its value is missing
/// (Principle IV).
library;

import 'package:flutter/material.dart';

import '../../auth/domain/auth_models.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    required this.user,
    this.onSignOut,
    this.deletionRequestedAt,
    super.key,
  });

  final AuthUser user;
  final Future<void> Function()? onSignOut;

  /// FR-017: set once deletion has been requested. Surfaced rather than hidden, because the
  /// account stays usable in the meantime and that is confusing without a word of explanation.
  final DateTime? deletionRequestedAt;

  static const String unnamedLabel = 'Your account';
  static const String signOutLabel = 'Sign out';
  static const String deletionPendingLabel = 'Account deletion requested';

  @override
  Widget build(BuildContext context) {
    final String name = user.displayName?.trim().isNotEmpty ?? false
        ? user.displayName!.trim()
        : unnamedLabel;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              _Avatar(user: user, name: name),
              const SizedBox(height: 16),
              Text(
                name,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              if (deletionRequestedAt != null) ...<Widget>[
                const SizedBox(height: 16),
                Text(
                  deletionPendingLabel,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Your orders will finish as normal until it is processed.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 32),
              if (onSignOut != null)
                OutlinedButton(
                  onPressed: onSignOut,
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: const Text(signOutLabel),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The avatar, with initials underneath the image rather than after it.
///
/// `foregroundImage` layers the photo over the initials, so a slow or failed load shows a
/// meaningful placeholder instead of a blank circle or a broken-image glyph — and no error path
/// has to be written for it (Principle IV: degradation is local).
class _Avatar extends StatelessWidget {
  const _Avatar({required this.user, required this.name});

  final AuthUser user;
  final String name;

  @override
  Widget build(BuildContext context) {
    final String initials = user.initials;
    final String? url = user.avatarUrl;

    return Semantics(
      label: 'Profile picture for $name',
      image: true,
      excludeSemantics: true,
      child: CircleAvatar(
        radius: 44,
        foregroundImage: url == null ? null : NetworkImage(url),
        // Required, not optional politeness: without an error listener a failed avatar fetch is
        // reported as an unhandled framework error. With one, the image simply does not appear
        // and the initials below stay visible — one broken asset, one local consequence.
        onForegroundImageError: url == null ? null : (Object _, StackTrace? __) {},
        child: initials.isEmpty
            ? const Icon(Icons.person_outline, size: 40)
            : Text(initials, style: Theme.of(context).textTheme.headlineMedium),
      ),
    );
  }
}
