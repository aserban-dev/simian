/// Parcel interpolation and the clamp (T091, T099).
///
/// FR-037 puts the position on the device; FR-038 clamps the elapsed fraction to 0..1 so a wrong
/// device clock cannot place the parcel outside the route. The clamp is the interesting part:
/// device clocks *are* wrong, sometimes by years, and without it the parcel is drawn somewhere
/// off the map with no error to explain it.
///
/// Every case here passes `now` explicitly — nothing in this file reads the real clock, which is
/// what makes "a clock set to 1970" an ordinary test rather than an impossible one.
library;

import 'package:dupermarket/features/orders/domain/parcel_position.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _start = DateTime.utc(2026, 8, 2, 12);

DeliveryTracking _tracking({
  GeoPoint origin = const GeoPoint(lat: 0, lng: 0),
  GeoPoint destination = const GeoPoint(lat: 10, lng: 20),
  int shippedHours = 6,
  int outForDeliveryHours = 54,
  int deliveredHours = 60,
}) =>
    DeliveryTracking(
      origin: origin,
      destination: destination,
      processingAt: _start,
      shippedAt: _start.add(Duration(hours: shippedHours)),
      outForDeliveryAt: _start.add(Duration(hours: outForDeliveryHours)),
      deliveredAt: _start.add(Duration(hours: deliveredHours)),
    );

void main() {
  group('elapsed fraction is clamped (T091, FR-038)', () {
    test('is 0 at the start of the window', () {
      expect(_tracking().elapsedFraction(_start), 0);
    });

    test('is 1 at the end of the window', () {
      expect(_tracking().elapsedFraction(_start.add(const Duration(hours: 60))), 1);
    });

    test('is 0.5 halfway through', () {
      expect(_tracking().elapsedFraction(_start.add(const Duration(hours: 30))), 0.5);
    });

    test('clamps to 0 for a clock set before the window', () {
      // The realistic version of this is a device whose clock is simply wrong.
      expect(_tracking().elapsedFraction(_start.subtract(const Duration(days: 3))), 0);
    });

    test('clamps to 0 for a clock set to the epoch', () {
      expect(_tracking().elapsedFraction(DateTime.utc(1970)), 0);
    });

    test('clamps to 1 for a clock set after the window', () {
      expect(_tracking().elapsedFraction(_start.add(const Duration(days: 400))), 1);
    });

    test('never leaves 0..1 for any clock', () {
      final tracking = _tracking();
      for (final Duration offset in <Duration>[
        const Duration(days: -3650),
        const Duration(hours: -1),
        Duration.zero,
        const Duration(hours: 1),
        const Duration(hours: 59),
        const Duration(hours: 60),
        const Duration(days: 3650),
      ]) {
        final double t = tracking.elapsedFraction(_start.add(offset));
        expect(t, inInclusiveRange(0, 1), reason: 'offset $offset produced $t');
      }
    });

    test('a zero-length window yields 1 rather than dividing by zero', () {
      final tracking = _tracking(shippedHours: 0, outForDeliveryHours: 0, deliveredHours: 0);

      expect(tracking.elapsedFraction(_start), 1);
    });
  });

  group('position interpolates between the endpoints (FR-037)', () {
    test('sits on the origin at the start', () {
      expect(_tracking().positionAt(_start), const GeoPoint(lat: 0, lng: 0));
    });

    test('sits on the destination at the end', () {
      expect(
        _tracking().positionAt(_start.add(const Duration(hours: 60))),
        const GeoPoint(lat: 10, lng: 20),
      );
    });

    test('sits at the midpoint halfway through', () {
      expect(
        _tracking().positionAt(_start.add(const Duration(hours: 30))),
        const GeoPoint(lat: 5, lng: 10),
      );
    });

    test('stays on the origin for a clock before the window', () {
      // The clamp's whole purpose: never off the route.
      expect(
        _tracking().positionAt(_start.subtract(const Duration(days: 30))),
        const GeoPoint(lat: 0, lng: 0),
      );
    });

    test('stays on the destination for a clock after the window', () {
      expect(
        _tracking().positionAt(_start.add(const Duration(days: 30))),
        const GeoPoint(lat: 10, lng: 20),
      );
    });

    test('handles negative coordinates', () {
      final tracking = _tracking(
        origin: const GeoPoint(lat: -10, lng: -20),
        destination: const GeoPoint(lat: 10, lng: 20),
      );

      expect(
        tracking.positionAt(_start.add(const Duration(hours: 30))),
        const GeoPoint(lat: 0, lng: 0),
      );
    });

    test('is deterministic for a given clock', () {
      final tracking = _tracking();
      final DateTime at = _start.add(const Duration(hours: 17));

      expect(tracking.positionAt(at), tracking.positionAt(at));
    });

    test('moves monotonically along the route', () {
      final tracking = _tracking();
      double previous = -1;
      for (var hour = 0; hour <= 60; hour += 5) {
        final GeoPoint point = tracking.positionAt(_start.add(Duration(hours: hour)));
        expect(point.lat, greaterThanOrEqualTo(previous));
        previous = point.lat;
      }
    });
  });

  group('stage derivation mirrors the server (FR-035)', () {
    test('is processing at the start', () {
      expect(_tracking().stageAt(_start), DeliveryStage.processing);
    });

    test('is shipped exactly on the shipped timestamp', () {
      expect(
        _tracking().stageAt(_start.add(const Duration(hours: 6))),
        DeliveryStage.shipped,
      );
    });

    test('is out for delivery exactly on its timestamp', () {
      expect(
        _tracking().stageAt(_start.add(const Duration(hours: 54))),
        DeliveryStage.outForDelivery,
      );
    });

    test('is delivered exactly on the delivered timestamp', () {
      expect(
        _tracking().stageAt(_start.add(const Duration(hours: 60))),
        DeliveryStage.delivered,
      );
    });

    test('stays delivered afterwards', () {
      expect(
        _tracking().stageAt(_start.add(const Duration(days: 365))),
        DeliveryStage.delivered,
      );
    });

    test('a clock before the window still reports a real stage', () {
      expect(
        _tracking().stageAt(_start.subtract(const Duration(days: 5))),
        DeliveryStage.processing,
      );
    });
  });

  group('the route seam (Principle V)', () {
    test('v1 draws a straight line between the endpoints', () {
      const provider = StraightLineRouteProvider();

      expect(
        provider.route(const GeoPoint(lat: 1, lng: 2), const GeoPoint(lat: 3, lng: 4)),
        <GeoPoint>[const GeoPoint(lat: 1, lng: 2), const GeoPoint(lat: 3, lng: 4)],
      );
    });

    test('a route always begins at the origin and ends at the destination', () {
      // The property any replacement must also satisfy — road routing included.
      const provider = StraightLineRouteProvider();
      const origin = GeoPoint(lat: 44.43, lng: 26.10);
      const destination = GeoPoint(lat: 52.23, lng: 21.01);

      final List<GeoPoint> route = provider.route(origin, destination);

      expect(route.first, origin);
      expect(route.last, destination);
    });
  });

  group('decoding the tracking payload', () {
    test('reads endpoints and all four stamps', () {
      final tracking = DeliveryTracking.fromJson(<String, dynamic>{
        'origin': <String, dynamic>{'lat': 44.43, 'lng': 26.10},
        'destination': <String, dynamic>{'lat': 52.23, 'lng': 21.01},
        'stages': <String, dynamic>{
          'processing_at': '2026-08-02T12:00:00Z',
          'shipped_at': '2026-08-02T18:00:00Z',
          'out_for_delivery_at': '2026-08-04T18:00:00Z',
          'delivered_at': '2026-08-05T00:00:00Z',
        },
      });

      expect(tracking.origin.lat, 44.43);
      expect(tracking.destination.lng, 21.01);
      expect(tracking.deliveredAt, DateTime.utc(2026, 8, 5));
    });

    test('a malformed payload degrades instead of throwing (Principle IV)', () {
      final tracking = DeliveryTracking.fromJson(<String, dynamic>{});

      expect(tracking.origin, const GeoPoint(lat: 0, lng: 0));
      expect(tracking.elapsedFraction(DateTime.utc(2026)), inInclusiveRange(0, 1));
    });
  });
}
