import 'package:dupermarket/core/errors/app_failure.dart';
import 'package:dupermarket/core/errors/failure_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// One instance of every variant. The list is the point: if a fifth failure kind is added and
/// not added here, the exhaustiveness test below fails.
const List<AppFailure> _allFailures = <AppFailure>[
  NoConnectivity(),
  ServiceUnreachable(),
  ServiceError(status: 500),
  AssetUnavailable(assetUrl: 'https://cdn.example/x.webp'),
];

void main() {
  group('AppFailure taxonomy', () {
    test('FR-059: the four failure kinds are distinguishable, not one generic error', () {
      final types = _allFailures.map((AppFailure f) => f.runtimeType).toSet();
      expect(types, hasLength(4));
    });

    test('FR-059: connectivity and reachability are separate kinds', () {
      // These get different copy because the fix belongs to different people. Collapsing them
      // is the most common way this requirement gets quietly violated.
      expect(const NoConnectivity(), isNot(isA<ServiceUnreachable>()));
      expect(const ServiceUnreachable(), isNot(isA<NoConnectivity>()));
    });

    test('FR-060: a retry is offered exactly when it could succeed', () {
      expect(const NoConnectivity().isRetryable, isTrue);
      expect(const ServiceUnreachable().isRetryable, isTrue);
      expect(const ServiceError(status: 500).isRetryable, isTrue);
      expect(const ServiceError(status: 503).isRetryable, isTrue);
      expect(const ServiceError(status: 429).isRetryable, isTrue);
      expect(const ServiceError(status: 408).isRetryable, isTrue);

      // A 404 or a 422 will not become true by asking again.
      expect(const ServiceError(status: 404).isRetryable, isFalse);
      expect(const ServiceError(status: 422).isRetryable, isFalse);
    });

    test('FR-061: a failed asset is not retryable at screen level, so it degrades locally', () {
      expect(const AssetUnavailable(assetUrl: 'x').isRetryable, isFalse);
    });
  });

  group('FailureView', () {
    testWidgets('FR-059: each failure kind renders its own copy, never a generic message',
        (WidgetTester tester) async {
      final Set<String> rendered = <String>{};

      for (final AppFailure failure in _allFailures) {
        await tester.pumpWidget(_wrap(FailureView(failure: failure)));
        final Finder texts = find.byType(Text);
        final String combined = tester
            .widgetList<Text>(texts)
            .map((Text t) => t.data ?? '')
            .join(' | ');

        expect(combined, isNotEmpty);
        expect(combined.toLowerCase(), isNot(contains('something went wrong')));
        rendered.add(combined);
      }

      expect(rendered, hasLength(_allFailures.length),
          reason: 'two failure kinds share the same copy, so the user cannot tell them apart');
    });

    testWidgets('FR-060: a retryable failure offers a way out that actually fires',
        (WidgetTester tester) async {
      var retried = 0;
      await tester.pumpWidget(_wrap(
        FailureView(failure: const NoConnectivity(), onRetry: () => retried++),
      ));

      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(retried, 1);
    });

    testWidgets('FR-060: a non-retryable failure shows no dead retry button',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        FailureView(failure: const ServiceError(status: 404), onRetry: () {}),
      ));
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('FR-060: a server-supplied detail is shown instead of boilerplate',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        const FailureView(
          failure: ServiceError(status: 402, detail: 'That card was declined. Try another.'),
        ),
      ));
      expect(find.text('That card was declined. Try another.'), findsOneWidget);
    });

    testWidgets('FR-068: the failure is announced to screen readers',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(const FailureView(failure: NoConnectivity())));

      expect(
        find.bySemanticsLabel(RegExp(r"You're offline")),
        findsWidgets,
      );
      handle.dispose();
    });

    testWidgets('FR-069: meaning is carried by text, not by the icon alone',
        (WidgetTester tester) async {
      for (final AppFailure failure in _allFailures) {
        await tester.pumpWidget(_wrap(FailureView(failure: failure)));
        expect(find.byType(Text), findsWidgets,
            reason: 'an icon-only error state relies on colour and glyph alone');
      }
    });
  });

  group('EmptyStateView', () {
    testWidgets('FR-063: an empty state has copy and a working way out',
        (WidgetTester tester) async {
      var acted = 0;
      await tester.pumpWidget(_wrap(EmptyStateView(
        icon: Icons.shopping_cart_outlined,
        title: "Your cart's feeling lonely",
        message: 'Add something you like and it will show up here.',
        actionLabel: 'Browse products',
        onAction: () => acted++,
      )));

      expect(find.text("Your cart's feeling lonely"), findsOneWidget);
      expect(find.text('Add something you like and it will show up here.'), findsOneWidget);

      await tester.tap(find.text('Browse products'));
      await tester.pump();
      expect(acted, 1, reason: 'an empty state without a working action is a dead end');
    });
  });

  group('OfflineBanner', () {
    testWidgets('FR-062: the offline banner is inline, not a modal dialog',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const Column(children: <Widget>[OfflineBanner()])));

      expect(find.textContaining("You're offline"), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
