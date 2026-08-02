/// The delivery map and the stage timeline (T095, T101).
///
/// FR-039: origin, destination, route and parcel position are all rendered, and the parcel sits
/// at the fraction the frozen clock implies.
///
/// A `GoogleMap` is a platform view, so nothing it draws exists in a widget test. What *does*
/// exist is the set of markers and polylines it is handed, and that is the whole of the
/// geometry — so the assertions are made against those rather than against pixels. The map
/// surface itself is left to manual and integration testing, which is where a platform view can
/// actually be exercised.
library;

import 'package:dupermarket/features/orders/domain/parcel_position.dart';
import 'package:dupermarket/features/orders/presentation/delivery_map.dart';
import 'package:dupermarket/features/orders/presentation/stage_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

final DateTime _start = DateTime.utc(2026, 8, 2, 12);

const GeoPoint _origin = GeoPoint(lat: 0, lng: 0);
const GeoPoint _destination = GeoPoint(lat: 10, lng: 20);

DeliveryTracking _tracking() => DeliveryTracking(
      origin: _origin,
      destination: _destination,
      processingAt: _start,
      shippedAt: _start.add(const Duration(hours: 6)),
      outForDeliveryAt: _start.add(const Duration(hours: 54)),
      deliveredAt: _start.add(const Duration(hours: 60)),
    );

DeliveryMap _map(DateTime now) => DeliveryMap(tracking: _tracking(), now: now);

Marker _markerNamed(DeliveryMap map, MarkerId id) =>
    map.markers.firstWhere((Marker m) => m.markerId == id);

void main() {
  group('what the map draws (T095, FR-039)', () {
    test('the origin is marked', () {
      expect(_markerNamed(_map(_start), kOriginMarkerId).position, const LatLng(0, 0));
    });

    test('the destination is marked', () {
      expect(
        _markerNamed(_map(_start), kDestinationMarkerId).position,
        const LatLng(10, 20),
      );
    });

    test('the route is drawn between the two endpoints', () {
      final Polyline route = _map(_start).polylines.single;

      expect(route.polylineId, kRoutePolylineId);
      expect(route.points.first, const LatLng(0, 0));
      expect(route.points.last, const LatLng(10, 20));
    });

    test('the parcel sits on the origin at the start of the window', () {
      expect(_markerNamed(_map(_start), kParcelMarkerId).position, const LatLng(0, 0));
    });

    test('the parcel sits at the halfway point midway through', () {
      final DeliveryMap map = _map(_start.add(const Duration(hours: 30)));

      expect(_markerNamed(map, kParcelMarkerId).position, const LatLng(5, 10));
    });

    test('the parcel sits on the destination at the end', () {
      final DeliveryMap map = _map(_start.add(const Duration(hours: 60)));

      expect(_markerNamed(map, kParcelMarkerId).position, const LatLng(10, 20));
    });

    test('a wrong clock cannot move the parcel off the route (FR-038)', () {
      final DeliveryMap early = _map(_start.subtract(const Duration(days: 100)));
      final DeliveryMap late = _map(_start.add(const Duration(days: 100)));

      expect(_markerNamed(early, kParcelMarkerId).position, const LatLng(0, 0));
      expect(_markerNamed(late, kParcelMarkerId).position, const LatLng(10, 20));
    });

    test('exactly three markers are drawn', () {
      expect(_map(_start).markers, hasLength(3));
    });

    test('the parcel marker announces the current stage', () {
      final DeliveryMap map = _map(_start.add(const Duration(hours: 55)));

      expect(
        _markerNamed(map, kParcelMarkerId).infoWindow.title,
        DeliveryStage.outForDelivery.label,
      );
    });

    test('the camera frames the whole journey rather than the parcel', () {
      expect(_map(_start).initialCamera.target, const LatLng(5, 10));
    });
  });

  group('the route seam (Principle V)', () {
    test('a different route provider changes the line without touching the map', () {
      final DeliveryMap map = DeliveryMap(
        tracking: _tracking(),
        now: _start,
        routeProvider: const _DoglegRouteProvider(),
      );

      expect(map.polylines.single.points, hasLength(3));
      expect(map.polylines.single.points.first, const LatLng(0, 0));
      expect(map.polylines.single.points.last, const LatLng(10, 20));
    });

    test('the markers are unaffected by the route provider', () {
      final DeliveryMap map = DeliveryMap(
        tracking: _tracking(),
        now: _start.add(const Duration(hours: 30)),
        routeProvider: const _DoglegRouteProvider(),
      );

      expect(_markerNamed(map, kParcelMarkerId).position, const LatLng(5, 10));
    });
  });

  group('the stage timeline (T101)', () {
    Future<void> pumpTimeline(WidgetTester tester, DateTime now) => tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: StageTimeline(tracking: _tracking(), now: now)),
          ),
        );

    testWidgets('lists all four stages, including ones still ahead', (
      WidgetTester tester,
    ) async {
      await pumpTimeline(tester, _start);

      for (final DeliveryStage stage in DeliveryStage.values) {
        expect(
          find.textContaining(stage.label),
          findsOneWidget,
          reason: '${stage.label} is missing from the timeline',
        );
      }
    });

    testWidgets('marks the current stage in words, not only by colour', (
      WidgetTester tester,
    ) async {
      await pumpTimeline(tester, _start.add(const Duration(hours: 55)));

      expect(
        find.text('${DeliveryStage.outForDelivery.label} — ${StageTimeline.currentSuffix}'),
        findsOneWidget,
      );
    });

    testWidgets('the current stage moves with the clock', (WidgetTester tester) async {
      await pumpTimeline(tester, _start.add(const Duration(hours: 7)));

      expect(
        find.text('${DeliveryStage.shipped.label} — ${StageTimeline.currentSuffix}'),
        findsOneWidget,
      );
    });

    testWidgets('completed stages are ticked', (WidgetTester tester) async {
      await pumpTimeline(tester, _start.add(const Duration(hours: 55)));

      // Processing and shipped are behind the current stage.
      expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
    });

    testWidgets('survives a 200% text scale (FR-067)', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(body: StageTimeline(tracking: _tracking(), now: _start)),
        ),
      ));

      expect(tester.takeException(), isNull);
    });
  });
}

/// A stand-in for road routing: same endpoints, an extra waypoint in between.
class _DoglegRouteProvider implements RouteProvider {
  const _DoglegRouteProvider();

  @override
  List<GeoPoint> route(GeoPoint origin, GeoPoint destination) => <GeoPoint>[
        origin,
        GeoPoint(lat: origin.lat, lng: destination.lng),
        destination,
      ];
}
