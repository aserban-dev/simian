import 'package:dupermarket/core/layout/breakpoints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Breakpoints', () {
    test('FR-065: real phone widths resolve to the two-column compact layout', () {
      // iPhone SE, iPhone 15, Pixel 8 — portrait logical widths.
      for (final width in <double>[320, 375, 393, 430]) {
        expect(Breakpoints.forWidth(width), LayoutClass.compact, reason: 'width $width');
        expect(Breakpoints.productColumns(Breakpoints.forWidth(width)), 2);
      }
    });

    test('FR-065: tablet widths give four to five columns', () {
      // iPad mini portrait, iPad Pro portrait, iPad Pro landscape.
      for (final width in <double>[744, 1024, 1366]) {
        final layout = Breakpoints.forWidth(width);
        expect(layout.isTablet, isTrue, reason: 'width $width');
        expect(Breakpoints.productColumns(layout), inInclusiveRange(4, 5));
      }
    });

    test('FR-065: the layout class changes at the boundary, not around it', () {
      expect(Breakpoints.forWidth(Breakpoints.medium - 0.1), LayoutClass.compact);
      expect(Breakpoints.forWidth(Breakpoints.medium), LayoutClass.medium);
      expect(Breakpoints.forWidth(Breakpoints.expanded - 0.1), LayoutClass.medium);
      expect(Breakpoints.forWidth(Breakpoints.expanded), LayoutClass.expanded);
    });

    test('FR-066: master-detail is used on tablets and never on phones', () {
      expect(Breakpoints.usesMasterDetail(LayoutClass.compact), isFalse);
      expect(Breakpoints.usesMasterDetail(LayoutClass.expanded), isTrue);
    });

    test('FR-065: column count never decreases as the screen widens', () {
      var previous = 0;
      for (final width in <double>[320, 600, 744, 900, 1366]) {
        final columns = Breakpoints.productColumns(Breakpoints.forWidth(width));
        expect(columns, greaterThanOrEqualTo(previous), reason: 'width $width');
        previous = columns;
      }
    });
  });
}
