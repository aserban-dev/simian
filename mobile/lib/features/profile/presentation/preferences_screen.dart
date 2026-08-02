/// Language, currency and notification preferences (T120).
///
/// Language and currency are separate controls on purpose (FR-049): reading the app in English
/// while paying in RON is an ordinary combination, and tying the two together would make it
/// unreachable.
///
/// Each list includes a "follow my device" option, because `null` is a real value here — it is
/// how a user goes back to the default rather than being stuck with a choice they once made.
library;

import 'package:flutter/material.dart';

import '../domain/preferences.dart';

class PreferencesScreen extends StatelessWidget {
  const PreferencesScreen({
    required this.preferences,
    required this.deviceLocale,
    this.onLanguageChanged,
    this.onCurrencyChanged,
    this.onNotificationChanged,
    super.key,
  });

  final UserPreferences preferences;
  final String deviceLocale;
  final void Function(String? language)? onLanguageChanged;
  final void Function(String? currency)? onCurrencyChanged;
  final void Function(String key, bool enabled)? onNotificationChanged;

  static const String title = 'Preferences';
  static const String languageLabel = 'Language';
  static const String currencyLabel = 'Currency';
  static const String notificationsLabel = 'Notifications';
  static const String followDeviceLabel = 'Follow my device';

  static const List<String> languages = <String>['en', 'ro', 'pl', 'de', 'fr', 'es'];
  static const List<String> currencies = <String>['EUR', 'USD', 'GBP', 'RON', 'PLN', 'SEK'];

  /// FR-046. Keyed rather than hardcoded so the server and the client agree on the names.
  static const Map<String, String> notificationKinds = <String, String>{
    'delivery': 'Delivery updates',
    'promotions': 'Offers and promotions',
  };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text(languageLabel, style: theme.textTheme.titleMedium),
            RadioGroup<String?>(
              groupValue: preferences.languageOverride,
              onChanged: (String? value) => onLanguageChanged?.call(value),
              child: Column(
                children: <Widget>[
                  RadioListTile<String?>(
                    value: null,
                    title: Text('$followDeviceLabel ($deviceLocale)'),
                  ),
                  for (final String code in languages)
                    RadioListTile<String?>(value: code, title: Text(code)),
                ],
              ),
            ),
            const Divider(height: 32),

            Text(currencyLabel, style: theme.textTheme.titleMedium),
            RadioGroup<String?>(
              groupValue: preferences.currencyOverride,
              onChanged: (String? value) => onCurrencyChanged?.call(value),
              child: Column(
                children: <Widget>[
                  RadioListTile<String?>(
                    value: null,
                    title: Text(
                      '$followDeviceLabel (${currencyForLocale(deviceLocale)})',
                    ),
                  ),
                  for (final String code in currencies)
                    RadioListTile<String?>(value: code, title: Text(code)),
                ],
              ),
            ),
            const Divider(height: 32),

            Text(notificationsLabel, style: theme.textTheme.titleMedium),
            for (final MapEntry<String, String> kind in notificationKinds.entries)
              SwitchListTile(
                value: preferences.isNotificationEnabled(kind.key),
                onChanged: onNotificationChanged == null
                    ? null
                    : (bool enabled) => onNotificationChanged!(kind.key, enabled),
                title: Text(kind.value),
              ),
          ],
        ),
      ),
    );
  }
}
