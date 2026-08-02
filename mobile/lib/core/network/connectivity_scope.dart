/// The offline banner, wired to the connectivity monitor (T134, T137).
///
/// FR-062: the banner appears when the connection is lost and clears when it returns. It sits
/// above the content rather than over it — Principle IV asks for inline and unobtrusive
/// messaging, and covering the screen the user is reading is exactly what "unobtrusive" rules
/// out. The cached content underneath stays visible and usable throughout.
library;

import 'package:flutter/material.dart';

import '../errors/failure_view.dart';
import 'connectivity.dart';

class ConnectivityScope extends StatefulWidget {
  const ConnectivityScope({
    required this.monitor,
    required this.child,
    super.key,
  });

  final ConnectivityMonitor monitor;
  final Widget child;

  @override
  State<ConnectivityScope> createState() => _ConnectivityScopeState();
}

class _ConnectivityScopeState extends State<ConnectivityScope> {
  late bool _online = widget.monitor.isOnline;

  @override
  void initState() {
    super.initState();
    // Seeded from `isOnline` above rather than waiting for the first event, so a screen opened
    // while already offline shows the banner immediately instead of on the next change.
    widget.monitor.changes.listen((bool online) {
      if (mounted) setState(() => _online = online);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        if (!_online) const OfflineBanner(),
        Expanded(child: widget.child),
      ],
    );
  }
}
