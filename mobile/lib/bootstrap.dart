import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config/app_environment.dart';

/// Shared startup path for all three flavors.
///
/// The flavor entrypoints differ only in the [Flavor] they pass; everything else is identical,
/// so there is exactly one place where startup order can go wrong.
Future<void> bootstrap(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  AppEnvironment.install(AppEnvironment.fromDartDefines(flavor));
  runApp(const DuperMarketApp());
}
