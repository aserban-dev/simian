/// Delivery notifications (T122, T123, T125, T126, T130).
///
/// The whole of FR-054 is testable here without a device because the scheduling decision is a
/// pure function of the order's immutable timestamps (research D6). Three properties matter:
///
/// * exactly three notifications, with ids derived from `order_id + stage` (T122);
/// * scheduling twice deduplicates rather than double-notifying (T123);
/// * a denied permission degrades nothing (T126, FR-056).
library;

import 'package:dupermarket/features/notifications/presentation/notification_permission_prompt.dart';
import 'package:dupermarket/features/notifications/scheduler.dart';
import 'package:dupermarket/features/orders/domain/parcel_position.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _placed = DateTime.utc(2026, 8, 2, 12);

DeliveryTracking _tracking() => DeliveryTracking(
      origin: const GeoPoint(lat: 0, lng: 0),
      destination: const GeoPoint(lat: 10, lng: 20),
      processingAt: _placed,
      shippedAt: _placed.add(const Duration(hours: 6)),
      outForDeliveryAt: _placed.add(const Duration(hours: 54)),
      deliveredAt: _placed.add(const Duration(hours: 60)),
    );

/// Records what was scheduled, the way the OS would: one entry per id, replaced on re-register.
class FakeNotificationPlatform implements NotificationPlatform {
  FakeNotificationPlatform({this.granted = true});

  final bool granted;
  final Map<int, ScheduledNotification> scheduled = <int, ScheduledNotification>{};
  final List<int> cancelled = <int>[];
  int scheduleCalls = 0;

  @override
  Future<bool> hasPermission() async => granted;

  @override
  Future<void> schedule(ScheduledNotification notification) async {
    scheduleCalls++;
    // Platform behaviour: an id that already exists is replaced, not added.
    scheduled[notification.id] = notification;
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduled.remove(id);
  }
}

void main() {
  group('what gets scheduled (T122, FR-054)', () {
    test('exactly three notifications are produced', () {
      final List<ScheduledNotification> due =
          notificationsFor(_tracking(), 'order-1', _placed);

      expect(due, hasLength(3));
    });

    test('they cover shipped, out for delivery and delivered', () {
      final List<ScheduledNotification> due =
          notificationsFor(_tracking(), 'order-1', _placed);

      expect(
        due.map((ScheduledNotification n) => n.stage),
        <DeliveryStage>[
          DeliveryStage.shipped,
          DeliveryStage.outForDelivery,
          DeliveryStage.delivered,
        ],
      );
    });

    test('processing is not notified', () {
      // It is true the instant the order is placed; a notification for the screen the user is
      // already looking at is noise.
      final List<ScheduledNotification> due =
          notificationsFor(_tracking(), 'order-1', _placed);

      expect(
        due.map((ScheduledNotification n) => n.stage),
        isNot(contains(DeliveryStage.processing)),
      );
    });

    test('each fires at its stage timestamp', () {
      final DeliveryTracking tracking = _tracking();
      final List<ScheduledNotification> due = notificationsFor(tracking, 'order-1', _placed);

      expect(due[0].scheduledFor, tracking.shippedAt);
      expect(due[1].scheduledFor, tracking.outForDeliveryAt);
      expect(due[2].scheduledFor, tracking.deliveredAt);
    });

    test('ids are derived from the order and the stage', () {
      final List<ScheduledNotification> due =
          notificationsFor(_tracking(), 'order-1', _placed);

      for (final ScheduledNotification notification in due) {
        expect(notification.id, notificationIdFor('order-1', notification.stage));
      }
    });

    test('ids are stable across calls', () {
      final first = notificationsFor(_tracking(), 'order-1', _placed);
      final second = notificationsFor(_tracking(), 'order-1', _placed);

      expect(
        first.map((ScheduledNotification n) => n.id),
        second.map((ScheduledNotification n) => n.id),
      );
    });

    test('different orders get different ids', () {
      final a = notificationsFor(_tracking(), 'order-1', _placed);
      final b = notificationsFor(_tracking(), 'order-2', _placed);

      expect(
        a.map((ScheduledNotification n) => n.id).toSet()
          ..retainAll(b.map((ScheduledNotification n) => n.id).toSet()),
        isEmpty,
      );
    });

    test('different stages of one order get different ids', () {
      final List<ScheduledNotification> due =
          notificationsFor(_tracking(), 'order-1', _placed);

      expect(due.map((ScheduledNotification n) => n.id).toSet(), hasLength(3));
    });

    test('ids fit in the platform range', () {
      // Android notification ids are 32-bit signed; an overflowing id is silently dropped,
      // which would look like "notifications do not work for some orders".
      for (var i = 0; i < 200; i++) {
        final int id = notificationIdFor('order-$i', DeliveryStage.delivered);
        expect(id, inInclusiveRange(0, 0x7fffffff));
      }
    });

    test('every notification carries copy a user can act on', () {
      final List<ScheduledNotification> due =
          notificationsFor(_tracking(), 'order-1', _placed);

      for (final ScheduledNotification notification in due) {
        expect(notification.title, isNotEmpty);
        expect(notification.body, isNotEmpty);
      }
    });

    test('stages already in the past are skipped', () {
      // A phone switched on after delivery must not fire "your order has shipped".
      final List<ScheduledNotification> due = notificationsFor(
        _tracking(),
        'order-1',
        _placed.add(const Duration(hours: 55)),
      );

      expect(due.map((ScheduledNotification n) => n.stage), <DeliveryStage>[
        DeliveryStage.delivered,
      ]);
    });

    test('a fully delivered order schedules nothing', () {
      final List<ScheduledNotification> due = notificationsFor(
        _tracking(),
        'order-1',
        _placed.add(const Duration(days: 30)),
      );

      expect(due, isEmpty);
    });
  });

  group('scheduling twice deduplicates (T123, FR-054)', () {
    test('the second run leaves three notifications, not six', () async {
      final platform = FakeNotificationPlatform();
      final scheduler = DeliveryNotificationScheduler(platform);

      await scheduler.scheduleForOrder(_tracking(), 'order-1', _placed);
      await scheduler.scheduleForOrder(_tracking(), 'order-1', _placed);

      expect(platform.scheduled, hasLength(3));
    });

    test('the ids are the same both times', () async {
      final platform = FakeNotificationPlatform();
      final scheduler = DeliveryNotificationScheduler(platform);

      final first = await scheduler.scheduleForOrder(_tracking(), 'order-1', _placed);
      final second = await scheduler.scheduleForOrder(_tracking(), 'order-1', _placed);

      expect(first.map((ScheduledNotification n) => n.id).toSet(),
          second.map((ScheduledNotification n) => n.id).toSet());
    });

    test('two different orders keep their own three each', () async {
      final platform = FakeNotificationPlatform();
      final scheduler = DeliveryNotificationScheduler(platform);

      await scheduler.scheduleForOrder(_tracking(), 'order-1', _placed);
      await scheduler.scheduleForOrder(_tracking(), 'order-2', _placed);

      expect(platform.scheduled, hasLength(6));
    });

    test('cancelling clears exactly that order', () async {
      final platform = FakeNotificationPlatform();
      final scheduler = DeliveryNotificationScheduler(platform);
      await scheduler.scheduleForOrder(_tracking(), 'order-1', _placed);
      await scheduler.scheduleForOrder(_tracking(), 'order-2', _placed);

      await scheduler.cancelForOrder('order-1');

      expect(platform.scheduled, hasLength(3));
      expect(
        platform.scheduled.values.map((ScheduledNotification n) => n.orderId).toSet(),
        <String>{'order-2'},
      );
    });
  });

  group('a denied permission degrades nothing (T126, FR-056)', () {
    test('scheduling is a quiet no-op rather than an error', () async {
      final platform = FakeNotificationPlatform(granted: false);

      final List<ScheduledNotification> due = await DeliveryNotificationScheduler(platform)
          .scheduleForOrder(_tracking(), 'order-1', _placed);

      expect(due, isEmpty);
      expect(platform.scheduleCalls, 0);
    });

    test('nothing throws, so no caller has to handle a failure', () async {
      final platform = FakeNotificationPlatform(granted: false);
      final scheduler = DeliveryNotificationScheduler(platform);

      // The assertion is that these complete at all.
      await scheduler.scheduleForOrder(_tracking(), 'order-1', _placed);
      await scheduler.cancelForOrder('order-1');
    });

    test('the order itself is unaffected — the notification is an extra, not a step', () async {
      final platform = FakeNotificationPlatform(granted: false);
      await DeliveryNotificationScheduler(platform)
          .scheduleForOrder(_tracking(), 'order-1', _placed);

      // The pure function still describes what *would* have been sent, so nothing about the
      // order's own data depends on permission.
      expect(notificationsFor(_tracking(), 'order-1', _placed), hasLength(3));
    });
  });

  group('when to ask (T125, FR-053)', () {
    test('never on first launch, before any order', () {
      expect(
        shouldAskForNotificationPermission(
          orderCount: 0,
          alreadyGranted: false,
          alreadyAsked: false,
        ),
        isFalse,
      );
    });

    test('after the first order', () {
      expect(
        shouldAskForNotificationPermission(
          orderCount: 1,
          alreadyGranted: false,
          alreadyAsked: false,
        ),
        isTrue,
      );
    });

    test('not again once granted', () {
      expect(
        shouldAskForNotificationPermission(
          orderCount: 3,
          alreadyGranted: true,
          alreadyAsked: true,
        ),
        isFalse,
      );
    });

    test('not again once asked, even if declined', () {
      // On iOS the system dialog can only be shown once; asking again does nothing and the
      // pre-prompt would just be nagging.
      expect(
        shouldAskForNotificationPermission(
          orderCount: 5,
          alreadyGranted: false,
          alreadyAsked: true,
        ),
        isFalse,
      );
    });
  });

  group('the permission prompt (T125, T129)', () {
    Future<void> pump(
      WidgetTester tester, {
      Future<void> Function()? onAllow,
      VoidCallback? onNotNow,
    }) =>
        tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: NotificationPermissionPrompt(
              onAllow: onAllow ?? () async {},
              onNotNow: onNotNow ?? () {},
            ),
          ),
        ));

    testWidgets('explains what will be sent before asking', (WidgetTester tester) async {
      await pump(tester);

      expect(find.text(NotificationPermissionPrompt.title), findsOneWidget);
      expect(find.text(NotificationPermissionPrompt.body), findsOneWidget);
    });

    testWidgets('names the three stages so the ask is specific', (WidgetTester tester) async {
      await pump(tester);

      final String body = NotificationPermissionPrompt.body.toLowerCase();
      expect(body, contains('ships'));
      expect(body, contains('out for delivery'));
      expect(body, contains('arrives'));
    });

    testWidgets('allowing triggers the request', (WidgetTester tester) async {
      var allowed = 0;
      await pump(tester, onAllow: () async => allowed++);

      await tester.tap(find.text(NotificationPermissionPrompt.allowLabel));
      await tester.pumpAndSettle();

      expect(allowed, 1);
    });

    testWidgets('declining is offered and costs nothing (FR-056)', (WidgetTester tester) async {
      var declined = 0;
      await pump(tester, onNotNow: () => declined++);

      await tester.tap(find.text(NotificationPermissionPrompt.notNowLabel));
      await tester.pumpAndSettle();

      expect(declined, 1);
    });

    testWidgets('survives a 200% text scale (FR-067)', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: NotificationPermissionPrompt(onAllow: () async {}, onNotNow: () {}),
            ),
          ),
        ),
      ));

      expect(tester.takeException(), isNull);
    });
  });

  group('deep links (T130, FR-055)', () {
    test('a notification carries a link to its order', () {
      final List<ScheduledNotification> due =
          notificationsFor(_tracking(), 'order-1', _placed);

      expect(due.first.deepLink, 'dupermarket://orders/order-1');
    });

    test('the order id round-trips out of the link', () {
      final ScheduledNotification notification =
          notificationsFor(_tracking(), 'order-abc', _placed).first;

      expect(orderIdFromDeepLink(notification.deepLink), 'order-abc');
    });

    test('every stage links to the same order', () {
      // All three taps land on one screen; the stage only changes what it says.
      for (final ScheduledNotification n in notificationsFor(_tracking(), 'order-1', _placed)) {
        expect(orderIdFromDeepLink(n.deepLink), 'order-1');
      }
    });

    test('a uuid-shaped id survives', () {
      const String id = '3f2504e0-4f89-11d3-9a0c-0305e82c3301';

      expect(orderIdFromDeepLink('dupermarket://orders/$id'), id);
    });

    test('an unrecognised link yields null rather than throwing', () {
      // The cold-start case: a bad link must open the app normally, not crash it on launch.
      for (final String? link in <String?>[
        null,
        '',
        'not a uri',
        'https://example.com/orders/1',
        'dupermarket://products/1',
        'dupermarket://orders',
      ]) {
        expect(orderIdFromDeepLink(link), isNull, reason: 'link: $link');
      }
    });
  });
}
