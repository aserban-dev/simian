/// The first-run welcome (T165, FR-080).
///
/// Shown to an account that has just been created and to nobody else. That distinction is the
/// only reason sign-up is a flow rather than a label (research D13), so it is enforced by a gate
/// widget rather than by each caller remembering to check a flag.
library;

import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({required this.onDismiss, super.key});

  final VoidCallback onDismiss;

  /// Principle IV: an interstitial with no way out is a dead end.
  static const String dismissLabel = 'Start shopping';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.storefront_outlined,
                    size: 72,
                    color: Theme.of(context).colorScheme.primary,
                    // Decorative: the heading below already carries the meaning, and announcing
                    // both would just repeat it (Principle VII).
                    semanticLabel: null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your account is ready',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Browse the aisles, save what you like, and track every delivery on a map.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: onDismiss,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    child: const Text(dismissLabel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows [WelcomeScreen] once to a new account, then [child] — and [child] straight away to a
/// returning one.
///
/// Stateful rather than a plain `if`, because "shown once" is the actual requirement: dismissing
/// it must not be undone by the next rebuild.
class WelcomeGate extends StatefulWidget {
  const WelcomeGate({
    required this.isNewUser,
    required this.child,
    super.key,
  });

  /// From `AuthResult.isNewUser`, which comes from the provider — not from a local heuristic
  /// like "has this device seen a sign-in before", which is wrong on a reinstall.
  final bool isNewUser;

  final Widget child;

  @override
  State<WelcomeGate> createState() => _WelcomeGateState();
}

class _WelcomeGateState extends State<WelcomeGate> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.isNewUser || _dismissed) return widget.child;
    return WelcomeScreen(onDismiss: () => setState(() => _dismissed = true));
  }
}
