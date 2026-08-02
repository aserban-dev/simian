/// Which providers to offer, per platform (FR-012).
///
/// Expressed as a function rather than a constant list because the requirement is conditional:
/// Apple must be offered on iOS *whenever any other social provider is*. Keeping that decision
/// in one pure function means the widget layer has no platform logic in it, and the invariant is
/// testable without pumping a widget.
library;

import 'package:flutter/foundation.dart';

import 'auth_models.dart';

/// The providers offered on [platform], in display order.
///
/// Every platform gets the full set. Apple's inclusion is mandatory on iOS and harmless
/// elsewhere, and offering the same three everywhere means a user who signed up with Apple on an
/// iPhone can still sign in on an Android tablet — the account is keyed on the Firebase UID, not
/// on the device.
List<SocialProvider> providersFor(TargetPlatform platform) => const <SocialProvider>[
      SocialProvider.google,
      SocialProvider.facebook,
      SocialProvider.apple,
    ];
