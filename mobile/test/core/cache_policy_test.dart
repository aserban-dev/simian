import 'package:dupermarket/core/cache/cache_policy.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _now = DateTime.utc(2026, 8, 2, 12);

void main() {
  const policy = CachePolicy(ttl: Duration(hours: 1));

  group('CachePolicy.decide', () {
    test('FR-057: an empty cache is a cold start, the only full-screen wait', () {
      expect(
        policy.decide(fetchedAt: null, now: _now),
        FetchReason.coldStart,
      );
    });

    test('FR-057: content inside the window renders without touching the network', () {
      final reason = policy.decide(
        fetchedAt: _now.subtract(const Duration(minutes: 59)),
        now: _now,
      );
      expect(reason, FetchReason.freshEnough);
      expect(policy.shouldFetch(reason), isFalse);
      expect(policy.hasContentToShow(reason), isTrue);
    });

    test('FR-057 + FR-058: stale content still renders, then refreshes behind it', () {
      final reason = policy.decide(
        fetchedAt: _now.subtract(const Duration(hours: 2)),
        now: _now,
      );
      expect(reason, FetchReason.staleRefresh);
      expect(policy.shouldFetch(reason), isTrue);
      expect(policy.hasContentToShow(reason), isTrue,
          reason: 'showing a spinner over content we already have is the FR-057 failure');
    });

    test('FR-058: pull-to-refresh fetches even when the cache is fresh', () {
      final reason = policy.decide(
        fetchedAt: _now.subtract(const Duration(seconds: 1)),
        now: _now,
        userRequested: true,
      );
      expect(reason, FetchReason.userRequested);
      expect(policy.shouldFetch(reason), isTrue);
    });

    test('FR-058: pull-to-refresh on an empty cache is not reported as a cold start', () {
      // Order matters here: a cold-start verdict would show the full-screen loader instead of
      // the pull-to-refresh indicator the user just triggered.
      expect(
        policy.decide(fetchedAt: null, now: _now, userRequested: true),
        FetchReason.userRequested,
      );
    });
  });

  group('expiry boundary', () {
    test('exactly at the TTL counts as expired', () {
      expect(
        policy.isExpired(fetchedAt: _now.subtract(const Duration(hours: 1)), now: _now),
        isTrue,
      );
    });

    test('one second inside the TTL is still fresh', () {
      expect(
        policy.isExpired(
          fetchedAt: _now.subtract(const Duration(minutes: 59, seconds: 59)),
          now: _now,
        ),
        isFalse,
      );
    });

    test('a cache stamped in the future is treated as expired, not as infinitely fresh', () {
      // Device clock changes and DST both produce this. Trusting the stamp would pin the app
      // to stale content with no way out.
      expect(
        policy.isExpired(fetchedAt: _now.add(const Duration(days: 1)), now: _now),
        isTrue,
      );
    });
  });

  test('the catalogue default matches the documented one-hour window', () {
    expect(CachePolicy.catalogue.ttl, const Duration(hours: 1));
  });
}
