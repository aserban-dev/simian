/// Reading and writing preference overrides (T120).
///
/// Written to two places, in this order: locally first, then to the profile. The local write is
/// what makes the change instant and what makes it survive a relaunch with no connection
/// (FR-049); the profile write is what makes it follow the user to another device (FR-048).
///
/// If the profile write fails the local one stands. The alternative — rolling the local change
/// back — would mean a user who changed currency on a train sees it snap back for no visible
/// reason, which is worse than a preference that syncs later.
library;

import 'package:drift/drift.dart';

import '../../../core/cache/cache_database.dart';
import '../../../core/network/api_client.dart';
import '../domain/preferences.dart';

const String languageKey = 'language_override';
const String currencyKey = 'currency_override';
const String notificationPrefix = 'notify.';

class PreferencesRepository {
  PreferencesRepository({required CacheDatabase cache, ApiClient? api})
      : _cache = cache,
        _api = api;

  final CacheDatabase _cache;

  /// Optional so the local half is usable before sign-in, when there is no profile to write to.
  final ApiClient? _api;

  Future<UserPreferences> read() async {
    final List<PreferenceEntry> rows = await _cache.select(_cache.preferenceEntries).get();
    final Map<String, String?> byKey = <String, String?>{
      for (final PreferenceEntry row in rows) row.key: row.value,
    };

    return UserPreferences(
      languageOverride: byKey[languageKey],
      currencyOverride: byKey[currencyKey],
      notificationPrefs: <String, bool>{
        for (final MapEntry<String, String?> entry in byKey.entries)
          if (entry.key.startsWith(notificationPrefix))
            entry.key.substring(notificationPrefix.length): entry.value == 'true',
      },
    );
  }

  Stream<UserPreferences> watch() =>
      _cache.select(_cache.preferenceEntries).watch().asyncMap((_) => read());

  /// FR-048. `null` clears the override and returns the user to the device language.
  Future<void> setLanguageOverride(String? language) async {
    await _write(languageKey, language);
    await _syncProfile(<String, dynamic>{'language_override': language});
  }

  /// FR-049. Independent of language — nothing here touches the language key.
  Future<void> setCurrencyOverride(String? currency) async {
    await _write(currencyKey, currency);
    await _syncProfile(<String, dynamic>{'currency_override': currency});
  }

  /// FR-046.
  Future<void> setNotificationPreference(String key, {required bool enabled}) async {
    await _write('$notificationPrefix$key', enabled.toString());
    final UserPreferences current = await read();
    await _syncProfile(<String, dynamic>{'notification_prefs': current.notificationPrefs});
  }

  /// Adopts what the profile says, without echoing it back to the server.
  ///
  /// Used after sign-in: the profile is authoritative across devices (FR-048), so a fresh
  /// install takes its overrides from there rather than starting at the device defaults.
  Future<void> adoptFromProfile(Map<String, dynamic> profile) async {
    await _write(languageKey, profile['language_override'] as String?);
    await _write(currencyKey, profile['currency_override'] as String?);

    final Object? prefs = profile['notification_prefs'];
    if (prefs is Map<String, dynamic>) {
      for (final MapEntry<String, dynamic> entry in prefs.entries) {
        await _write('$notificationPrefix${entry.key}', '${entry.value == true}');
      }
    }
  }

  Future<void> _write(String key, String? value) async {
    if (value == null) {
      await (_cache.delete(_cache.preferenceEntries)
            ..where(($PreferenceEntriesTable t) => t.key.equals(key)))
          .go();
      return;
    }
    await _cache.into(_cache.preferenceEntries).insertOnConflictUpdate(
          PreferenceEntriesCompanion.insert(key: key, value: Value<String?>(value)),
        );
  }

  /// Best-effort. See the library comment: a failed sync must not undo the local change.
  Future<void> _syncProfile(Map<String, dynamic> body) async {
    final ApiClient? api = _api;
    if (api == null) return;
    try {
      await api.patchJson('/me', body: body);
    } on ApiException {
      // Swallowed deliberately: the preference is applied locally and will sync next time.
    }
  }
}
