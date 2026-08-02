/// The delivery map (T100).
///
/// FR-039: origin, destination, the route between them, and the current parcel position. The
/// position is computed here from the injected clock and the stored window — never fetched, and
/// never held by the server (FR-037).
///
/// The route geometry comes from a [RouteProvider] rather than being drawn inline. Today's
/// implementation returns the two endpoints and the map draws a straight line; swapping in road
/// routing is then a change to one class, with no change to this widget, the model, or the data
/// schema (Principle V).
library;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../domain/parcel_position.dart';

/// Ids are stable so the map diffs markers between rebuilds rather than recreating them, which
/// is what makes the parcel glide instead of blink.
const MarkerId kOriginMarkerId = MarkerId('origin');
const MarkerId kDestinationMarkerId = MarkerId('destination');
const MarkerId kParcelMarkerId = MarkerId('parcel');
const PolylineId kRoutePolylineId = PolylineId('route');

class DeliveryMap extends StatelessWidget {
  const DeliveryMap({
    required this.tracking,
    required this.now,
    this.routeProvider = const StraightLineRouteProvider(),
    super.key,
  });

  final DeliveryTracking tracking;

  /// Injected rather than read here, so the map is testable at any point in the window and so
  /// the whole screen shares one notion of "now" (Principle III).
  final DateTime now;

  final RouteProvider routeProvider;

  /// Everything the map draws, exposed so a widget test can assert the geometry without a
  /// platform view. The map surface itself cannot render in a test; what it is *asked* to draw
  /// can be checked exactly.
  Set<Marker> get markers {
    final GeoPoint parcel = tracking.positionAt(now);
    return <Marker>{
      Marker(
        markerId: kOriginMarkerId,
        position: _toLatLng(tracking.origin),
        infoWindow: const InfoWindow(title: 'Dispatched from'),
      ),
      Marker(
        markerId: kDestinationMarkerId,
        position: _toLatLng(tracking.destination),
        infoWindow: const InfoWindow(title: 'Delivering to'),
      ),
      Marker(
        markerId: kParcelMarkerId,
        position: _toLatLng(parcel),
        infoWindow: InfoWindow(title: tracking.stageAt(now).label),
      ),
    };
  }

  Set<Polyline> get polylines => <Polyline>{
        Polyline(
          polylineId: kRoutePolylineId,
          width: 4,
          points: <LatLng>[
            for (final GeoPoint point
                in routeProvider.route(tracking.origin, tracking.destination))
              _toLatLng(point),
          ],
        ),
      };

  /// Frames the whole journey rather than centring on the parcel: a user opening the screen
  /// wants to see how far it has to go, not a close-up of a van.
  CameraPosition get initialCamera => CameraPosition(
        target: _toLatLng(
          GeoPoint(
            lat: (tracking.origin.lat + tracking.destination.lat) / 2,
            lng: (tracking.origin.lng + tracking.destination.lng) / 2,
          ),
        ),
        zoom: 5,
      );

  static LatLng _toLatLng(GeoPoint point) => LatLng(point.lat, point.lng);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // Principle VII: a map is invisible to a screen reader, so the state it conveys is said
      // in words rather than left to the pins.
      label: 'Delivery map. ${tracking.stageAt(now).label}, '
          '${(tracking.elapsedFraction(now) * 100).round()} percent of the way.',
      child: GoogleMap(
        initialCameraPosition: initialCamera,
        markers: markers,
        polylines: polylines,
        liteModeEnabled: false,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
      ),
    );
  }
}
