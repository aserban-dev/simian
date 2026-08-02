/// Language, currency and notification preferences (T120).
///
/// Three requirements meet here, and they are deliberately independent of each other:
///
/// * **FR-047** — language defaults to the device locale, and any string with no translation
///   falls back to English rather than showing a key.
/// * **FR-048** — the language override lives on the *profile*, so it follows the user to
///   another device. The local copy is a mirror for launch-time rendering, not the truth.
/// * **FR-049** — currency defaults from the device locale and is overridable **independently**
///   of language. A user reading English in Bucharest still wants prices in RON.
library;

import 'package:meta/meta.dart';

/// The language a string is written in when nothing else matches (FR-047).
const String fallbackLanguage = 'en';

/// Resolves a translated string.
///
/// The same rule the backend applies to its localised JSON columns: requested locale, then
/// English, then empty — never the key. A key on screen is a bug report from the user's point
/// of view; an English string is merely untranslated.
String localise(Map<String, String> translations, String locale) {
  final String exact = translations[locale] ?? '';
  if (exact.isNotEmpty) return exact;

  // `ro-RO` should find a `ro` translation before falling back to English.
  final String language = locale.split(RegExp('[-_]')).first;
  final String byLanguage = translations[language] ?? '';
  if (byLanguage.isNotEmpty) return byLanguage;

  return translations[fallbackLanguage] ?? '';
}

/// Currency for a locale, when the user has not chosen one (FR-049).
///
/// A small table rather than a general mapping: this app ships to a handful of countries, and
/// an incomplete lookup that quietly returns the wrong currency would be worse than a default.
const Map<String, String> _localeCurrencies = <String, String>{
  'RO': 'RON',
  'PL': 'PLN',
  'SE': 'SEK',
  'GB': 'GBP',
  'US': 'USD',
  'IE': 'EUR',
  'DE': 'EUR',
  'FR': 'EUR',
  'ES': 'EUR',
  'IT': 'EUR',
  'NL': 'EUR',
  'BE': 'EUR',
};

const String defaultCurrency = 'EUR';

String currencyForLocale(String locale) {
  final List<String> parts = locale.split(RegExp('[-_]'));
  if (parts.length < 2) return defaultCurrency;
  return _localeCurrencies[parts[1].toUpperCase()] ?? defaultCurrency;
}

@immutable
class UserPreferences {
  const UserPreferences({
    this.languageOverride,
    this.currencyOverride,
    this.notificationPrefs = const <String, bool>{},
  });

  /// Null means "follow the device" — the same meaning the API gives it.
  final String? languageOverride;
  final String? currencyOverride;

  /// FR-046. Absent keys are opt-in defaults decided by the caller, not stored as false, so a
  /// preference added later does not arrive switched off for everyone.
  final Map<String, bool> notificationPrefs;

  /// FR-047 / FR-048: the override if set, otherwise the device.
  String activeLanguage(String deviceLocale) =>
      (languageOverride?.isNotEmpty ?? false) ? languageOverride! : deviceLocale;

  /// FR-049: resolved independently of language — the override, else the device's currency.
  String activeCurrency(String deviceLocale) =>
      (currencyOverride?.isNotEmpty ?? false) ? currencyOverride! : currencyForLocale(deviceLocale);

  bool isNotificationEnabled(String key, {bool orElse = true}) =>
      notificationPrefs[key] ?? orElse;

  UserPreferences copyWith({
    String? languageOverride,
    String? currencyOverride,
    Map<String, bool>? notificationPrefs,
    bool clearLanguage = false,
    bool clearCurrency = false,
  }) =>
      UserPreferences(
        languageOverride: clearLanguage ? null : languageOverride ?? this.languageOverride,
        currencyOverride: clearCurrency ? null : currencyOverride ?? this.currencyOverride,
        notificationPrefs: notificationPrefs ?? this.notificationPrefs,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserPreferences &&
          other.languageOverride == languageOverride &&
          other.currencyOverride == currencyOverride;

  @override
  int get hashCode => Object.hash(languageOverride, currencyOverride);
}
