/// Where the parcel is (T099).
///
/// FR-037: the position is computed **on the device** by interpolating between origin and
/// destination using the elapsed fraction of the delivery window. The server sends endpoints and
/// timestamps and never a position — a server-held position would be a value that has to be
/// refreshed, which is the background progression Principle III forbids.
///
/// FR-038: the fraction is clamped to 0..1. That single `clamp` is what makes a wrong device
/// clock a cosmetic problem instead of a parcel drawn in the sea — and it is why this is a pure
/// function with an injected `now` rather than something that reads the clock itself.
library;

import 'package:meta/meta.dart';

@immutable
class GeoPoint {
  const GeoPoint({required this.lat, required this.lng});

  final double lat;
  final double lng;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => 'GeoPoint($lat, $lng)';
}

/// The delivery stages, in order. The names match the contract's `DeliveryStage` enum.
enum DeliveryStage {
  processing,
  shipped,
  outForDelivery,
  delivered;

  static DeliveryStage parse(Object? raw) => switch (raw) {
        'processing' => DeliveryStage.processing,
        'shipped' => DeliveryStage.shipped,
        'out_for_delivery' => DeliveryStage.outForDelivery,
        'delivered' => DeliveryStage.delivered,
        // An unknown stage must not blank the screen; the earliest is the safe reading.
        _ => DeliveryStage.processing,
      };

  String get label => switch (this) {
        DeliveryStage.processing => 'Processing',
        DeliveryStage.shipped => 'Shipped',
        DeliveryStage.outForDelivery => 'Out for delivery',
        DeliveryStage.delivered => 'Delivered',
      };
}

/// A delivery as the client needs it: two endpoints and four timestamps.
@immutable
class DeliveryTracking {
  const DeliveryTracking({
    required this.origin,
    required this.destination,
    required this.processingAt,
    required this.shippedAt,
    required this.outForDeliveryAt,
    required this.deliveredAt,
  });

  final GeoPoint origin;
  final GeoPoint destination;
  final DateTime processingAt;
  final DateTime shippedAt;
  final DateTime outForDeliveryAt;
  final DateTime deliveredAt;

  DateTime get windowStart => processingAt;
  DateTime get windowEnd => deliveredAt;

  /// FR-038 — the clamp, and the only place it happens.
  ///
  /// A zero-length window (every stage at the same instant) would divide by zero. It is
  /// degenerate but representable, and the honest answer for "the whole window has elapsed" is
  /// 1, not a crash.
  double elapsedFraction(DateTime now) {
    final int total = windowEnd.difference(windowStart).inMilliseconds;
    if (total <= 0) return 1;

    final int elapsed = now.difference(windowStart).inMilliseconds;
    return (elapsed / total).clamp(0, 1).toDouble();
  }

  /// FR-037: linear interpolation along the path between the endpoints.
  ///
  /// Straight-line in geographic coordinates, which is what the map draws today. When road
  /// routing replaces it the *route* changes (see `RouteProvider`), not this rule.
  GeoPoint positionAt(DateTime now) {
    final double t = elapsedFraction(now);
    return GeoPoint(
      lat: origin.lat + (destination.lat - origin.lat) * t,
      lng: origin.lng + (destination.lng - origin.lng) * t,
    );
  }

  /// FR-035, mirrored from the server so the map stays live between fetches.
  ///
  /// Derived from the same stored timestamps the server used, so the two cannot disagree — and
  /// checked latest-boundary-first, so a clock in either direction still yields a real stage.
  DeliveryStage stageAt(DateTime now) {
    if (!now.isBefore(deliveredAt)) return DeliveryStage.delivered;
    if (!now.isBefore(outForDeliveryAt)) return DeliveryStage.outForDelivery;
    if (!now.isBefore(shippedAt)) return DeliveryStage.shipped;
    return DeliveryStage.processing;
  }

  factory DeliveryTracking.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> stages = (json['stages'] as Map<String, dynamic>?) ?? const {};
    GeoPoint point(String key) {
      final Map<String, dynamic> raw = (json[key] as Map<String, dynamic>?) ?? const {};
      return GeoPoint(
        lat: (raw['lat'] as num?)?.toDouble() ?? 0,
        lng: (raw['lng'] as num?)?.toDouble() ?? 0,
      );
    }

    DateTime stamp(String key) =>
        DateTime.tryParse(stages[key] as String? ?? '')?.toUtc() ?? DateTime.utc(1970);

    return DeliveryTracking(
      origin: point('origin'),
      destination: point('destination'),
      processingAt: stamp('processing_at'),
      shippedAt: stamp('shipped_at'),
      outForDeliveryAt: stamp('out_for_delivery_at'),
      deliveredAt: stamp('delivered_at'),
    );
  }
}

/// The route drawn between origin and destination (Principle V).
///
/// One interface, so replacing the straight line with a real road route is a change to an
/// implementation and not to the map, the model, or the data schema.
abstract interface class RouteProvider {
  List<GeoPoint> route(GeoPoint origin, GeoPoint destination);
}

/// v1: the two endpoints, drawn as a straight line.
class StraightLineRouteProvider implements RouteProvider {
  const StraightLineRouteProvider();

  @override
  List<GeoPoint> route(GeoPoint origin, GeoPoint destination) =>
      <GeoPoint>[origin, destination];
}
