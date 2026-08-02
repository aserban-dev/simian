/// The contextual permission prompt (T129).
///
/// FR-053: permission is requested **after a user's first order**, never on first launch. The
/// reason is not politeness — a system dialog shown before the user has any reason to say yes
/// is usually denied, and on iOS a denial is close to permanent: the app cannot ask again, and
/// the user has to find the setting themselves.
///
/// So this is a pre-prompt. It explains what the notifications are for and only then triggers
/// the system dialog, and declining here costs nothing — the OS was never asked, so the app can
/// ask again after the next order.
library;

import 'package:flutter/material.dart';

class NotificationPermissionPrompt extends StatelessWidget {
  const NotificationPermissionPrompt({
    required this.onAllow,
    required this.onNotNow,
    super.key,
  });

  final Future<void> Function() onAllow;
  final VoidCallback onNotNow;

  static const String title = 'Want delivery updates?';

  /// Says what will be sent and when. A prompt that says only "enable notifications" is asking
  /// the user to guess.
  static const String body =
      'We can let you know when your order ships, when it is out for delivery, and when it '
      'arrives. Three messages per order, nothing else.';

  static const String allowLabel = 'Keep me posted';
  static const String notNowLabel = 'Not now';

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(body, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onAllow,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text(allowLabel),
          ),
          const SizedBox(height: 8),
          // FR-056: declining is a first-class outcome, not a dead end. Same weight of wording,
          // and nothing else on the screen changes.
          TextButton(onPressed: onNotNow, child: const Text(notNowLabel)),
        ],
      ),
    );
  }
}

/// Decides whether to show the pre-prompt.
///
/// Pure, so FR-053's "not on first launch" is testable without a device: it is a function of
/// how many orders exist and whether the OS has already been asked.
bool shouldAskForNotificationPermission({
  required int orderCount,
  required bool alreadyGranted,
  required bool alreadyAsked,
}) {
  if (alreadyGranted || alreadyAsked) return false;
  // FR-053: after the *first order*, not before it.
  return orderCount >= 1;
}
