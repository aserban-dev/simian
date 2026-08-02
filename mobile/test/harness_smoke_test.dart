// Toolchain smoke test.
//
// Its only job is to prove the Flutter test harness is wired up and runnable before any
// feature code exists, so that `flutter test` in CI is meaningful from day one rather than
// erroring on an empty test directory.
//
// The real client tests land with /speckit-implement. Each one carries the FR-xxx it covers
// in its description, which is how `scripts/check_traceability.py` finds it:
//
//   testWidgets('FR-061: a failed image shows a placeholder without breaking the grid', ...)
//
// Planned suites, by task:
//   T031  error-state widgets, one per AppFailure variant          FR-059, FR-060
//   T034  currency conversion and base-currency fallback           FR-050, FR-051, FR-052
//   T037  golden matrix: 3 layouts x 2 text scales                 FR-065..FR-067
//   T045  empty states                                             FR-063
//   T046  per-tile image failure                                   FR-061
//   T076  cart persistence and offline mutability                  FR-019
//   T078  offline checkout refusal                                 FR-029
//   T095  delivery map rendering against a frozen clock            FR-039
//   T099  clamped parcel interpolation                             FR-037, FR-038
//   T131  cache-then-network render order                          FR-057
//   T134  offline banner                                           FR-062

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('test harness', () {
    test('flutter_test is available and assertions run', () {
      expect(1 + 1, equals(2));
    });

    test('async assertions run', () async {
      await expectLater(Future<int>.value(42), completion(equals(42)));
    });
  });
}
