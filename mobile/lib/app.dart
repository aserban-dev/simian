import 'package:flutter/material.dart';

import 'core/layout/breakpoints.dart';

/// The application shell.
///
/// Feature screens are wired in from Phase 3 (`/speckit-implement`, tasks T054–T059). What is
/// here now is the part the whole app inherits: theming that honours the OS text scale
/// (FR-067), and a home that already switches layout by breakpoint rather than scaling
/// (FR-065).
class DuperMarketApp extends StatelessWidget {
  const DuperMarketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DuperMarket',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      // FR-067: there is deliberately no `builder` clamping the text scaler here. Flutter
      // honours the OS font-size setting by default, and wrapping the app in a clamp — the
      // usual shortcut when a layout overflows at large sizes — would defeat the requirement
      // outright. Layouts are made to cope instead, and the 2.0x golden tests (T037, T059)
      // keep them honest.
      home: const _HomePlaceholder(),
    );
  }

  static ThemeData _theme(Brightness brightness) => ThemeData(
        useMaterial3: true,
        brightness: brightness,
        colorSchemeSeed: const Color(0xFFFF6B00),
      );
}

class _HomePlaceholder extends StatelessWidget {
  const _HomePlaceholder();

  @override
  Widget build(BuildContext context) {
    final layout = Breakpoints.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('DuperMarket')),
      // FR-070: respect safe areas, notches, and cutouts everywhere, not per-screen.
      body: SafeArea(
        child: Center(
          child: Text(
            'Catalogue arrives with Phase 3 (US1).\n'
            'Layout class: ${layout.name} — '
            '${Breakpoints.productColumns(layout)} product columns.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
