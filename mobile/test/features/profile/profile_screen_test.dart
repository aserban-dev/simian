/// The profile screen (T069).
///
/// Shows the display name and avatar the provider supplied. Everything here is a Principle IV
/// or VII concern: an account with no name, or an avatar that will not load, must still render
/// something meaningful rather than an empty box or a broken-image icon.
library;

import 'package:dupermarket/features/auth/domain/auth_models.dart';
import 'package:dupermarket/features/profile/presentation/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

const AuthUser _named = AuthUser(
  uid: 'uid-1',
  displayName: 'Sam Shopper',
  avatarUrl: 'https://cdn.test/a.png',
);

void main() {
  testWidgets('shows the display name', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(const ProfileScreen(user: _named)));

    expect(find.text('Sam Shopper'), findsOneWidget);
  });

  testWidgets('falls back to initials when the avatar cannot be loaded', (
    WidgetTester tester,
  ) async {
    // There is no network in a widget test, so this exercises the real error path.
    await tester.pumpWidget(_wrap(const ProfileScreen(user: _named)));
    await tester.pump();

    expect(find.text('SS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an account with no name still renders (Apple with Hide My Email)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(const ProfileScreen(user: AuthUser(uid: 'uid-2'))));

    expect(find.text(ProfileScreen.unnamedLabel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offers sign-out', (WidgetTester tester) async {
    var signedOut = 0;
    await tester.pumpWidget(_wrap(ProfileScreen(
      user: _named,
      onSignOut: () async => signedOut++,
    )));

    await tester.tap(find.text(ProfileScreen.signOutLabel));
    await tester.pumpAndSettle();

    expect(signedOut, 1);
  });

  testWidgets('surfaces a pending deletion request rather than hiding it (FR-017)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(ProfileScreen(
      user: _named,
      deletionRequestedAt: DateTime.utc(2026, 8, 2),
    )));

    expect(find.text(ProfileScreen.deletionPendingLabel), findsOneWidget);
  });

  testWidgets('says nothing about deletion when none was requested', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(const ProfileScreen(user: _named)));

    expect(find.text(ProfileScreen.deletionPendingLabel), findsNothing);
  });

  testWidgets('the avatar carries a semantic label (Principle VII)', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();

    await tester.pumpWidget(_wrap(const ProfileScreen(user: _named)));

    expect(find.bySemanticsLabel('Profile picture for Sam Shopper'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('survives a 200% text scale (FR-067)', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(2)),
        child: ProfileScreen(user: _named),
      ),
    ));

    expect(tester.takeException(), isNull);
  });
}
