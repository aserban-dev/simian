/// Sign up or sign in (T066).
///
/// One screen for both, because with social providers they are the same authorisation call — the
/// difference is whether the account already existed, which only the provider can tell us
/// (research D13). Hence one set of buttons and no mode toggle.
///
/// FR-011 is visible in what is *absent*: no password field, no registration form, no email
/// verification step. There is nothing here to fill in.
library;

import 'package:flutter/material.dart';

import '../domain/auth_models.dart';

/// One provider button. Its label is also its screen-reader label (Principle VII).
class SocialSignInButton extends StatelessWidget {
  const SocialSignInButton({
    required this.provider,
    required this.onPressed,
    super.key,
  });

  final SocialProvider provider;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          // Principle VII: a comfortable target at any text scale, and it grows rather than
          // clipping when the label wraps.
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        child: Text('Continue with ${provider.label}', textAlign: TextAlign.center),
      ),
    );
  }
}

class SignInScreen extends StatefulWidget {
  const SignInScreen({
    required this.providers,
    required this.onSignIn,
    super.key,
  });

  /// Supplied rather than resolved here, so the screen has no platform logic in it and the
  /// FR-012 rule stays in one testable place (`providersFor`).
  final List<SocialProvider> providers;

  final Future<void> Function(SocialProvider provider) onSignIn;

  /// Principle IV: a failure says what to do next, and the buttons stay live.
  static const String failureMessage = "We couldn't sign you in. Please try again.";

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _busy = false;
  bool _failed = false;

  Future<void> _attempt(SocialProvider provider) async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await widget.onSignIn(provider);
    } on Object {
      // The provider's own error text is not fit to show a user, and often names the SDK.
      if (mounted) setState(() => _failed = true);
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // FR-070: safe areas honoured here rather than per widget.
      body: SafeArea(
        child: Center(
          // Scrollable so a 200% text scale lengthens the page instead of overflowing it
          // (FR-067) — the layout copes rather than clamping the scaler.
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Welcome to DuperMarket',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in or create an account — no password needed.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  for (final SocialProvider provider in widget.providers)
                    SocialSignInButton(
                      provider: provider,
                      onPressed: _busy ? null : () => _attempt(provider),
                    ),
                  if (_failed) ...<Widget>[
                    const SizedBox(height: 16),
                    Text(
                      SignInScreen.failureMessage,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
