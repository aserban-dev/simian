/// Knowing whether there is a connection (T137).
///
/// Two consumers, wanting different things:
///
/// * [ApiClient] needs a **synchronous** answer at failure-mapping time. Without it, "offline"
///   and "the backend is down" are the same socket error, and FR-059 requires them to be told
///   apart — the first says "you're offline", the second says "we're having a moment".
/// * The offline banner needs a **stream**, so it can appear on loss and clear on restore
///   (FR-062).
///
/// So this holds the last known value and publishes changes. It is an interface first and a
/// `connectivity_plus` adapter second, because a widget test cannot install a platform channel
/// and because "offline" has to be an ordinary state to write a test for, not a device setting.
library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

abstract interface class ConnectivityMonitor {
  /// The last known state, available synchronously. Optimistic before the first reading: a
  /// false "offline" would suppress a request that would have worked, which is worse than a
  /// request that fails and is then correctly diagnosed.
  bool get isOnline;

  /// Emits on every change. Implementations must not emit duplicates — a banner that rebuilds
  /// on every poll would flicker.
  Stream<bool> get changes;

  Future<void> dispose();
}

/// The `connectivity_plus` implementation. The only file in the app that imports the plugin.
///
/// "Has a network interface" is not the same as "can reach the server", and this deliberately
/// reports the former: it is what the OS can tell us cheaply and synchronously. The latter is
/// discovered by a request failing, which the failure mapper already handles.
class PlatformConnectivityMonitor implements ConnectivityMonitor {
  PlatformConnectivityMonitor({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity() {
    _subscription = _connectivity.onConnectivityChanged.listen(_onResults);
    unawaited(_prime());
  }

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  bool _isOnline = true;

  @override
  bool get isOnline => _isOnline;

  @override
  Stream<bool> get changes => _controller.stream;

  Future<void> _prime() async {
    try {
      _onResults(await _connectivity.checkConnectivity());
    } on Object {
      // A platform that cannot answer is not a reason to declare the user offline.
    }
  }

  void _onResults(List<ConnectivityResult> results) {
    final bool online = results.any((ConnectivityResult r) => r != ConnectivityResult.none);
    if (online == _isOnline) return; // no duplicates: see `changes`
    _isOnline = online;
    _controller.add(online);
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    await _controller.close();
  }
}

/// An in-memory monitor, for tests and for the signed-out shell before the plugin is wired.
///
/// Not test-only: it is also the honest default on a platform where connectivity cannot be
/// observed, where assuming "online" and letting requests fail is the correct behaviour.
class FakeConnectivityMonitor implements ConnectivityMonitor {
  FakeConnectivityMonitor({bool online = true}) : _isOnline = online;

  bool _isOnline;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  @override
  bool get isOnline => _isOnline;

  @override
  Stream<bool> get changes => _controller.stream;

  void set(bool online) {
    if (online == _isOnline) return;
    _isOnline = online;
    _controller.add(online);
  }

  @override
  Future<void> dispose() async => _controller.close();
}
