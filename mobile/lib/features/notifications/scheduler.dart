/// Delivery notifications without a scheduler (T128).
///
/// Research D6 and FR-054. This is the one place where the source specification and its own
/// constraints pulled against each other: §10 wants a notification at each stage change, while
/// FR-035 forbids any background progression — so **no component ever observes a transition**
/// and a server has nothing to push on.
///
/// The resolution is that there is nothing to observe. All four stage timestamps are assigned at
/// order creation and are immutable (FR-033, FR-034), so the device can schedule every
/// notification the moment the order exists. No cron, no timer function, no idempotency ledger,
/// and it keeps working while the backend is down.
///
/// The scheduling decision is a **pure function** — `(order, now) -> List<ScheduledNotification>`
/// — so all of FR-054 is testable without a device, a clock, or a notification plugin.
library;

import 'package:meta/meta.dart';

import '../orders/domain/parcel_position.dart';

/// The three stages a user is notified about.
///
/// `processing` is absent on purpose: it is true the instant the order is placed, and a
/// notification for something the user is already looking at is noise.
const List<DeliveryStage> notifiedStages = <DeliveryStage>[
  DeliveryStage.shipped,
  DeliveryStage.outForDelivery,
  DeliveryStage.delivered,
];

@immutable
class ScheduledNotification {
  const ScheduledNotification({
    required this.id,
    required this.orderId,
    required this.stage,
    required this.scheduledFor,
    required this.title,
    required this.body,
  });

  /// Stable and derived from `orderId + stage` (FR-054).
  ///
  /// This is what makes "at most once per stage per order" a property of the identifier rather
  /// than of bookkeeping: scheduling the same order twice re-registers the same three ids, and
  /// the OS replaces rather than adds. There is no ledger to keep in step.
  final int id;

  final String orderId;
  final DeliveryStage stage;
  final DateTime scheduledFor;
  final String title;
  final String body;

  /// FR-055: what a tap has to carry so the app can open the right order.
  String get deepLink => 'dupermarket://orders/$orderId';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduledNotification &&
          other.id == id &&
          other.orderId == orderId &&
          other.stage == stage &&
          other.scheduledFor == scheduledFor;

  @override
  int get hashCode => Object.hash(id, orderId, stage, scheduledFor);

  @override
  String toString() => 'ScheduledNotification($id, $orderId, ${stage.name}, $scheduledFor)';
}

/// A stable 31-bit id for one order-and-stage pair.
///
/// Platform notification ids are 32-bit signed on Android, so the hash is masked rather than
/// used raw — an id that overflows is silently rejected by the platform, which would look
/// exactly like "notifications do not work on some orders".
int notificationIdFor(String orderId, DeliveryStage stage) =>
    Object.hash(orderId, stage.name) & 0x7fffffff;

/// Every notification an order still needs, given the current time.
///
/// Stages already in the past are skipped: an order placed while the phone was off should not
/// fire "your order has shipped" at the moment it is switched back on, hours after delivery.
List<ScheduledNotification> notificationsFor(
  DeliveryTracking tracking,
  String orderId,
  DateTime now,
) {
  final Map<DeliveryStage, DateTime> times = <DeliveryStage, DateTime>{
    DeliveryStage.shipped: tracking.shippedAt,
    DeliveryStage.outForDelivery: tracking.outForDeliveryAt,
    DeliveryStage.delivered: tracking.deliveredAt,
  };

  return <ScheduledNotification>[
    for (final DeliveryStage stage in notifiedStages)
      if (!times[stage]!.isBefore(now))
        ScheduledNotification(
          id: notificationIdFor(orderId, stage),
          orderId: orderId,
          stage: stage,
          scheduledFor: times[stage]!,
          title: _titleFor(stage),
          body: _bodyFor(stage),
        ),
  ];
}

String _titleFor(DeliveryStage stage) => switch (stage) {
      DeliveryStage.shipped => 'Your order is on its way',
      DeliveryStage.outForDelivery => 'Out for delivery',
      DeliveryStage.delivered => 'Delivered',
      DeliveryStage.processing => 'Order placed',
    };

String _bodyFor(DeliveryStage stage) => switch (stage) {
      DeliveryStage.shipped => 'It has left the warehouse. Tap to follow it on the map.',
      DeliveryStage.outForDelivery => 'It is with the driver and arriving soon.',
      DeliveryStage.delivered => 'Your order has arrived. Tap to see the details.',
      DeliveryStage.processing => 'We are getting your order ready.',
    };

/// What actually talks to the platform. Kept behind an interface so the rules above stay
/// testable and so a denied permission is a no-op rather than a crash (FR-056).
abstract interface class NotificationPlatform {
  Future<bool> hasPermission();
  Future<void> schedule(ScheduledNotification notification);
  Future<void> cancel(int id);
}

/// Schedules delivery notifications for an order.
///
/// Every method is safe to call with permission denied or revoked: the scheduler asks first and
/// returns quietly. FR-056 requires that a denied permission degrade nothing else, and the way
/// to guarantee that is for this class to have no failure mode a caller must handle.
class DeliveryNotificationScheduler {
  DeliveryNotificationScheduler(this._platform);

  final NotificationPlatform _platform;

  /// Schedules the outstanding notifications for [orderId].
  ///
  /// Idempotent by construction (FR-054): ids are derived, so calling twice re-registers the
  /// same ones. Returns what was scheduled, which is what the tests assert on.
  Future<List<ScheduledNotification>> scheduleForOrder(
    DeliveryTracking tracking,
    String orderId,
    DateTime now,
  ) async {
    if (!await _platform.hasPermission()) return const <ScheduledNotification>[];

    final List<ScheduledNotification> due = notificationsFor(tracking, orderId, now);
    for (final ScheduledNotification notification in due) {
      await _platform.schedule(notification);
    }
    return due;
  }

  /// Used when an order can no longer progress — currently only for tests and future
  /// cancellation; the delivery simulation itself never reverses.
  Future<void> cancelForOrder(String orderId) async {
    for (final DeliveryStage stage in notifiedStages) {
      await _platform.cancel(notificationIdFor(orderId, stage));
    }
  }
}

/// Parses the order id out of a notification's deep link (FR-055).
///
/// Returns null for anything unrecognised rather than throwing: a tap that cannot be resolved
/// should open the app normally, not crash it on launch — which is the cold-start case.
String? orderIdFromDeepLink(String? link) {
  if (link == null || link.isEmpty) return null;
  final Uri? uri = Uri.tryParse(link);
  if (uri == null || uri.scheme != 'dupermarket') return null;

  final List<String> segments = <String>[uri.host, ...uri.pathSegments]
      .where((String s) => s.isNotEmpty)
      .toList();
  if (segments.length < 2 || segments.first != 'orders') return null;
  return segments[1];
}
