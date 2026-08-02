/// Build-time environment configuration.
///
/// The three flavors (`dev`, `staging`, `prod`) differ only in the values below. Everything
/// downstream reads [AppEnvironment.current], so no feature code branches on flavor — a flavor
/// check scattered through feature code is how staging behaviour leaks into production.
///
/// Values arrive via `--dart-define`, not a checked-in file, so no key is ever committed.
library;

enum Flavor { dev, staging, prod }

class AppEnvironment {
  const AppEnvironment({
    required this.flavor,
    required this.apiBaseUrl,
    required this.firebaseProjectId,
    required this.mapsApiKey,
    required this.catalogueCacheTtl,
  });

  final Flavor flavor;
  final String apiBaseUrl;
  final String firebaseProjectId;
  final String mapsApiKey;

  /// FR-058: cached catalogue content expires after a defined freshness window.
  final Duration catalogueCacheTtl;

  static AppEnvironment? _current;

  static AppEnvironment get current {
    final env = _current;
    if (env == null) {
      throw StateError(
        'AppEnvironment.install() must be called from the flavor entrypoint before runApp.',
      );
    }
    return env;
  }

  static void install(AppEnvironment environment) => _current = environment;

  /// Visible for testing — lets a test install a fake environment and restore afterwards.
  static void reset() => _current = null;

  bool get isProduction => flavor == Flavor.prod;

  static AppEnvironment fromDartDefines(Flavor flavor) {
    const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
    const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const mapsApiKey = String.fromEnvironment('MAPS_API_KEY');
    const ttlSeconds = int.fromEnvironment('CATALOGUE_CACHE_TTL_SECONDS', defaultValue: 3600);

    // Fail at startup with a message naming the variable, rather than at first use with a
    // confusing 404 or an empty map. Mirrors the backend's fail-fast settings behaviour.
    if (apiBaseUrl.isEmpty) {
      throw StateError('API_BASE_URL is not set. Pass it with --dart-define.');
    }
    if (firebaseProjectId.isEmpty) {
      throw StateError('FIREBASE_PROJECT_ID is not set. Pass it with --dart-define.');
    }

    return AppEnvironment(
      flavor: flavor,
      apiBaseUrl: apiBaseUrl,
      firebaseProjectId: firebaseProjectId,
      mapsApiKey: mapsApiKey,
      catalogueCacheTtl: const Duration(seconds: ttlSeconds),
    );
  }
}
