/// Layout breakpoints.
///
/// FR-065 requires layout to *switch* at breakpoints rather than scale a fixed phone design,
/// and pins the product grid to roughly two columns on phones and four to five on tablets.
/// FR-066 requires tablets to support master–detail in both orientations.
///
/// Column counts live here rather than in each screen so "roughly two columns on a phone" has
/// exactly one definition that the golden tests (T037, T059) can assert against.
library;

import 'package:flutter/widgets.dart';

enum LayoutClass {
  /// Phones in portrait, and anything unexpectedly narrow.
  compact,

  /// Large phones in landscape, small tablets in portrait.
  medium,

  /// Tablets, and anything wider.
  expanded;

  bool get isTablet => this != LayoutClass.compact;
}

abstract final class Breakpoints {
  /// Chosen to sit above large phones in portrait (≈430 dp) and below tablets in portrait
  /// (≈768 dp), so a phone never lands in `medium` while upright.
  static const double medium = 600;
  static const double expanded = 900;

  static LayoutClass of(BuildContext context) =>
      forWidth(MediaQuery.sizeOf(context).width);

  static LayoutClass forWidth(double width) {
    if (width >= expanded) return LayoutClass.expanded;
    if (width >= medium) return LayoutClass.medium;
    return LayoutClass.compact;
  }

  /// Product grid columns per layout class (FR-065).
  static int productColumns(LayoutClass layout) => switch (layout) {
        LayoutClass.compact => 2,
        LayoutClass.medium => 4,
        LayoutClass.expanded => 5,
      };

  /// FR-066: master–detail only where there is room for both panes to stay usable.
  static bool usesMasterDetail(LayoutClass layout) => layout == LayoutClass.expanded;
}
