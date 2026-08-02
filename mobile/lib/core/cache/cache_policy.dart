/// Freshness rules for cached content.
///
/// FR-057: render from cache immediately, then refresh in the background.
/// FR-058: cached catalogue content expires after a defined window, and pull-to-refresh forces
/// a fetch regardless of that window.
///
/// Pure and clock-injected, so every branch is testable without waiting (Principle III).
library;

import 'package:meta/meta.dart';

/// Why a fetch is happening — or not.
enum FetchReason {
  /// Nothing cached. The user waits, so this is the only case that shows a full-screen
  /// loading state rather than content.
  coldStart,

  /// Cached content is inside its window. Render it, and do not hit the network.
  freshEnough,

  /// Cached content is past its window. Render it anyway (FR-057), then refresh behind it.
  staleRefresh,

  /// The user pulled to refresh. Always fetches, whatever the TTL says (FR-058).
  userRequested,
}

@immutable
class CachePolicy {
  const CachePolicy({required this.ttl});

  /// Default matches `CATALOGUE_CACHE_TTL_SECONDS` in `.env.example`.
  static const CachePolicy catalogue = CachePolicy(ttl: Duration(hours: 1));

  final Duration ttl;

  /// Decide what to do for a collection last fetched at [fetchedAt].
  FetchReason decide({
    required DateTime? fetchedAt,
    required DateTime now,
    bool userRequested = false,
  }) {
    // Checked before the cold-start branch: pull-to-refresh on an empty cache is still a
    // user-requested fetch, and reporting it as a cold start would show the wrong UI.
    if (userRequested) return FetchReason.userRequested;
    if (fetchedAt == null) return FetchReason.coldStart;
    return isExpired(fetchedAt: fetchedAt, now: now)
        ? FetchReason.staleRefresh
        : FetchReason.freshEnough;
  }

  bool isExpired({required DateTime fetchedAt, required DateTime now}) {
    // A clock that has gone backwards (device time changed, DST) would otherwise make cached
    // content look arbitrarily fresh. Treat any negative age as expired.
    final Duration age = now.difference(fetchedAt);
    if (age.isNegative) return true;
    return age >= ttl;
  }

  /// Whether the network should be consulted at all.
  bool shouldFetch(FetchReason reason) => reason != FetchReason.freshEnough;

  /// Whether cached content exists to render while any fetch runs (FR-057).
  bool hasContentToShow(FetchReason reason) => reason != FetchReason.coldStart;
}
