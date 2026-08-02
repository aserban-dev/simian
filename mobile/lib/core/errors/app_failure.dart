/// The failure taxonomy.
///
/// FR-059 requires four failure kinds to be distinguished and handled separately, and FR-060
/// requires every one of them to offer a way forward. A sealed class makes both mechanical:
/// `switch` over an [AppFailure] is exhaustive, so adding a fifth kind breaks compilation at
/// every place that renders one, rather than silently falling through to a generic "something
/// went wrong" — which is the dead end Principle IV forbids.
///
/// Raw exceptions and status codes never reach the UI; they are mapped here first.
library;

import 'package:meta/meta.dart';

@immutable
sealed class AppFailure {
  const AppFailure({required this.cause});

  /// The underlying error, for logging only. Never rendered.
  final Object? cause;

  /// Whether offering a retry makes sense. A retry that cannot succeed is worse than none.
  bool get isRetryable;
}

/// The device has no usable network connection. Distinct from [ServiceUnreachable]: the fix is
/// the user's to make, so the copy says so.
final class NoConnectivity extends AppFailure {
  const NoConnectivity({super.cause});

  @override
  bool get isRetryable => true;
}

/// The device is online but the backend did not answer — DNS, timeout, connection refused.
final class ServiceUnreachable extends AppFailure {
  const ServiceUnreachable({super.cause, this.timedOut = false});

  final bool timedOut;

  @override
  bool get isRetryable => true;
}

/// The backend answered with an error. [status] and [detail] come from the RFC 9457 problem
/// document; [detail] is written to be safe to show a user.
final class ServiceError extends AppFailure {
  const ServiceError({
    required this.status,
    this.detail,
    this.retryable = false,
    super.cause,
  });

  final int status;
  final String? detail;
  final bool retryable;

  /// 4xx other than 408/429 will not succeed on retry, so do not offer one.
  @override
  bool get isRetryable =>
      retryable || status >= 500 || status == 408 || status == 429;
}

/// A single asset failed to load. FR-061: this degrades one tile, never its siblings, so it is
/// deliberately not retryable at the screen level — the image widget handles its own retry.
final class AssetUnavailable extends AppFailure {
  const AssetUnavailable({required this.assetUrl, super.cause});

  final String assetUrl;

  @override
  bool get isRetryable => false;
}
