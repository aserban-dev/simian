/// The sign-up / sign-in screen (T066) and the first-run welcome (T165).
///
/// FR-011: no password, no registration form, no email verification — on *either* path.
/// FR-012: Apple is offered for both on iOS whenever another provider is.
/// FR-080: the welcome is shown to a new account and not to a returning one.
library;

import 'package:dupermarket/features/auth/domain/auth_models.dart';
import 'package:dupermarket/features/auth/domain/provider_menu.dart';
import 'package:dupermarket/features/auth/presentation/sign_in_screen.dart';
import 'package:dupermarket/features/auth/presentation/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  group('provider menu (FR-012)', () {
    test('Apple is offered on iOS, where the App Store requires it', () {
      expect(providersFor(TargetPlatform.iOS), contains(SocialProvider.apple));
    });

    test('the other providers are offered on iOS too', () {
      final List<SocialProvider> menu = providersFor(TargetPlatform.iOS);
      expect(menu, containsAll(<SocialProvider>[SocialProvider.google, SocialProvider.facebook]));
    });

    test('Apple appears wherever another social provider does, on every platform', () {
      // FR-012 phrased as an invariant rather than a platform list, so a new platform cannot
      // quietly ship without it.
      for (final TargetPlatform platform in TargetPlatform.values) {
        final List<SocialProvider> menu = providersFor(platform);
        if (menu.isEmpty) continue;
        expect(
          menu,
          contains(SocialProvider.apple),
          reason: 'Apple must accompany any social provider on $platform',
        );
      }
    });

    test('no platform is left with nothing to sign in with (Principle IV)', () {
      for (final TargetPlatform platform in TargetPlatform.values) {
        expect(providersFor(platform), isNotEmpty, reason: '$platform has no way in');
      }
    });
  });

  group('sign-in screen (T066, FR-011)', () {
    testWidgets('offers a button per provider', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(SignInScreen(
        providers: const <SocialProvider>[
          SocialProvider.google,
          SocialProvider.facebook,
          SocialProvider.apple,
        ],
        onSignIn: (SocialProvider _) async {},
      )));

      expect(find.byType(SocialSignInButton), findsNWidgets(3));
    });

    testWidgets('has no password field, no form, and no email verification step', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(SignInScreen(
        providers: const <SocialProvider>[SocialProvider.google, SocialProvider.apple],
        onSignIn: (SocialProvider _) async {},
      )));

      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byType(Form), findsNothing);
    });

    testWidgets('tapping a provider reports which one was chosen', (WidgetTester tester) async {
      final chosen = <SocialProvider>[];
      await tester.pumpWidget(_wrap(SignInScreen(
        providers: const <SocialProvider>[SocialProvider.google, SocialProvider.apple],
        onSignIn: (SocialProvider p) async => chosen.add(p),
      )));

      await tester.tap(find.widgetWithText(SocialSignInButton, 'Continue with Apple'));
      await tester.pumpAndSettle();

      expect(chosen, <SocialProvider>[SocialProvider.apple]);
    });

    testWidgets('a failed sign-in leaves a retry rather than a dead end (Principle IV)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(SignInScreen(
        providers: const <SocialProvider>[SocialProvider.google],
        onSignIn: (SocialProvider _) async => throw StateError('provider unreachable'),
      )));

      await tester.tap(find.byType(SocialSignInButton));
      await tester.pumpAndSettle();

      expect(find.text(SignInScreen.failureMessage), findsOneWidget);
      expect(find.byType(SocialSignInButton), findsOneWidget, reason: 'still retryable');
    });

    testWidgets('every provider button carries a screen-reader label (Principle VII)', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(SignInScreen(
        providers: const <SocialProvider>[SocialProvider.google, SocialProvider.apple],
        onSignIn: (SocialProvider _) async {},
      )));

      for (final SocialProvider p in <SocialProvider>[
        SocialProvider.google,
        SocialProvider.apple,
      ]) {
        expect(find.bySemanticsLabel('Continue with ${p.label}'), findsOneWidget);
      }
      handle.dispose();
    });

    testWidgets('survives a 200% text scale without overflowing (FR-067)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: SignInScreen(
            providers: const <SocialProvider>[
              SocialProvider.google,
              SocialProvider.facebook,
              SocialProvider.apple,
            ],
            onSignIn: (SocialProvider _) async {},
          ),
        ),
      ));

      expect(tester.takeException(), isNull);
    });
  });

  group('first-run welcome (T165, FR-080)', () {
    testWidgets('a new account is welcomed', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const WelcomeGate(
        isNewUser: true,
        child: Text('home'),
      )));

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text('home'), findsNothing);
    });

    testWidgets('a returning user goes straight in', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const WelcomeGate(
        isNewUser: false,
        child: Text('home'),
      )));

      expect(find.byType(WelcomeScreen), findsNothing);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('dismissing the welcome reveals the app and does not show it again', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const WelcomeGate(
        isNewUser: true,
        child: Text('home'),
      )));

      await tester.tap(find.text(WelcomeScreen.dismissLabel));
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
      expect(find.byType(WelcomeScreen), findsNothing);
    });

    testWidgets('the welcome offers a way forward, never a dead end (Principle IV)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const WelcomeGate(isNewUser: true, child: Text('home'))));

      expect(find.widgetWithText(FilledButton, WelcomeScreen.dismissLabel), findsOneWidget);
    });
  });
}
