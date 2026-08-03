/// Tablet master–detail and skeleton loaders (T156, T157).
///
/// FR-066: on a tablet the catalogue is a two-pane arrangement, not a scaled-up phone screen.
/// FR-064: screens with a predictable layout show a skeleton while they load.
library;

import 'package:dupermarket/core/layout/breakpoints.dart';
import 'package:dupermarket/core/layout/list_skeleton.dart';
import 'package:dupermarket/features/catalogue/presentation/master_detail_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpAt(WidgetTester tester, double width, Widget child) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pump();
}

Widget scaffold({bool hasSelection = true}) => MasterDetailScaffold(
      master: const Text('master pane'),
      detail: const Text('detail pane'),
      hasSelection: hasSelection,
    );

void main() {
  group('master–detail appears only where there is room (T156, FR-066)', () {
    testWidgets('a phone shows the list alone', (WidgetTester tester) async {
      await pumpAt(tester, 390, scaffold());

      expect(find.text('master pane'), findsOneWidget);
      expect(find.text('detail pane'), findsNothing);
    });

    testWidgets('a small tablet still shows one pane', (WidgetTester tester) async {
      // Medium is four product columns, not two panes — cramming a detail pane in beside a
      // four-column grid leaves neither usable.
      await pumpAt(tester, 700, scaffold());

      expect(find.text('detail pane'), findsNothing);
    });

    testWidgets('a large tablet shows both panes', (WidgetTester tester) async {
      await pumpAt(tester, 1200, scaffold());

      expect(find.text('master pane'), findsOneWidget);
      expect(find.text('detail pane'), findsOneWidget);
    });

    testWidgets('the empty detail pane says what to do (FR-063)', (WidgetTester tester) async {
      // FR-063 applies to a pane as much as to a screen.
      await pumpAt(tester, 1200, scaffold(hasSelection: false));

      expect(find.text(MasterDetailScaffold.noSelectionLabel), findsOneWidget);
    });

    testWidgets('a supplied empty pane is used instead', (WidgetTester tester) async {
      await pumpAt(
        tester,
        1200,
        const MasterDetailScaffold(
          master: Text('master pane'),
          detail: Text('detail pane'),
          hasSelection: false,
          emptyDetail: Text('nothing picked'),
        ),
      );

      expect(find.text('nothing picked'), findsOneWidget);
    });

    testWidgets('rotating from phone to tablet width switches layout', (
      WidgetTester tester,
    ) async {
      // FR-065: layouts switch at breakpoints rather than scaling.
      await pumpAt(tester, 390, scaffold());
      expect(find.text('detail pane'), findsNothing);

      tester.view.physicalSize = const Size(1200, 1000);
      await tester.pumpAndSettle();

      expect(find.text('detail pane'), findsOneWidget);
    });

    test('the breakpoint rule is the shared one', () {
      expect(Breakpoints.usesMasterDetail(LayoutClass.compact), isFalse);
      expect(Breakpoints.usesMasterDetail(LayoutClass.medium), isFalse);
      expect(Breakpoints.usesMasterDetail(LayoutClass.expanded), isTrue);
    });
  });

  group('skeleton loaders (T157, FR-064)', () {
    testWidgets('a list skeleton renders the requested number of rows', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, 390, const ListSkeleton(rows: 5));

      expect(find.byType(SkeletonBlock), findsNWidgets(10)); // two lines per row
    });

    testWidgets('a single-line skeleton renders one block per row', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, 390, const ListSkeleton(rows: 4, hasSecondLine: false));

      expect(find.byType(SkeletonBlock), findsNWidgets(4));
    });

    testWidgets('it announces itself as loading rather than reading out boxes', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpAt(tester, 390, const ListSkeleton());

      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('it does not animate', (WidgetTester tester) async {
      // A shimmer is motion the user did not ask for; `pumpAndSettle` would time out on one.
      await pumpAt(tester, 390, const ListSkeleton());

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('it survives a 200% text scale (FR-067)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(body: ListSkeleton()),
        ),
      ));

      expect(tester.takeException(), isNull);
    });
  });
}
