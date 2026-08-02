/// Error and empty states.
///
/// FR-060: every error state offers a retry or an alternative action — no dead ends.
/// FR-063: every empty state carries explanatory copy and a primary action.
/// Principle IV: messaging is inline and unobtrusive by default; no modal dialogs here.
library;

import 'package:flutter/material.dart';

import 'app_failure.dart';

/// Inline, non-modal presentation of an [AppFailure].
///
/// The `switch` is exhaustive over the sealed hierarchy, so adding a failure kind without
/// giving it copy is a compile error rather than a generic fallback message.
class FailureView extends StatelessWidget {
  const FailureView({required this.failure, this.onRetry, super.key});

  final AppFailure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final (title, body) = _copyFor(failure);
    final theme = Theme.of(context);

    return Semantics(
      container: true,
      liveRegion: true,
      label: '$title. $body',
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // FR-069: the icon supports the text, it does not replace it. Meaning is never
            // carried by colour or glyph alone.
            Icon(_iconFor(failure), size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(body, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            if (failure.isRetryable && onRetry != null) ...<Widget>[
              const SizedBox(height: 16),
              // FR-060: the way out. Minimum touch target comes from the button itself.
              FilledButton.tonal(onPressed: onRetry, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(AppFailure failure) => switch (failure) {
        NoConnectivity() => Icons.wifi_off_outlined,
        ServiceUnreachable() => Icons.cloud_off_outlined,
        ServiceError() => Icons.error_outline,
        AssetUnavailable() => Icons.image_not_supported_outlined,
      };

  /// Copy is deliberately specific per kind — "something went wrong" tells the user nothing
  /// about whether the fix is theirs to make, which is the whole point of FR-059.
  static (String, String) _copyFor(AppFailure failure) => switch (failure) {
        NoConnectivity() => (
            "You're offline",
            'Check your connection and try again. Everything you’ve already browsed is '
                'still here.',
          ),
        ServiceUnreachable(timedOut: final timedOut) => (
            timedOut ? 'That took too long' : "We can't reach the shop",
            'Your connection looks fine, so this is on our side. Give it another go.',
          ),
        ServiceError(status: final status, detail: final detail) => (
            status >= 500 ? 'Something broke on our side' : "That didn't work",
            detail ?? 'Please try again in a moment.',
          ),
        AssetUnavailable() => ('Image unavailable', "This picture didn't load."),
      };
}

/// FR-063: an empty state is helpful, not blank — illustration, a line of copy, a way out.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: '$title. $message',
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 56, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

/// FR-062: persistent but unobtrusive while offline. A banner, never a dialog.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: Material(
        color: theme.colorScheme.secondaryContainer,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: <Widget>[
                Icon(Icons.wifi_off_outlined,
                    size: 18, color: theme.colorScheme.onSecondaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "You're offline — showing what we already have",
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSecondaryContainer),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
