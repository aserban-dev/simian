/// Tablet master–detail for the catalogue (T156, FR-066).
///
/// On an expanded layout the list and the selected product sit side by side; on anything
/// narrower the detail is a pushed route, as it always was. `Breakpoints.usesMasterDetail`
/// decides, so the threshold lives with the other layout constants rather than here.
///
/// The rule this encodes is FR-065's, not a visual preference: layouts **switch** at
/// breakpoints rather than scaling a phone design up. A two-pane tablet view is a different
/// arrangement of the same content, not a bigger version of the same arrangement.
library;

import 'package:flutter/material.dart';

import '../../../core/layout/breakpoints.dart';

class MasterDetailScaffold extends StatelessWidget {
  const MasterDetailScaffold({
    required this.master,
    required this.detail,
    required this.hasSelection,
    this.emptyDetail,
    this.masterFlex = 2,
    this.detailFlex = 3,
    super.key,
  });

  /// The list. Always shown.
  final Widget master;

  /// The selected item's detail. Shown beside the list on an expanded layout.
  final Widget detail;

  /// Whether anything is selected. With nothing selected the detail pane shows [emptyDetail]
  /// rather than a blank half-screen — FR-063 applies to a pane as much as to a screen.
  final bool hasSelection;

  final Widget? emptyDetail;
  final int masterFlex;
  final int detailFlex;

  static const String noSelectionLabel = 'Pick something to see it here';

  @override
  Widget build(BuildContext context) {
    final LayoutClass layout = Breakpoints.of(context);

    // Narrow: one pane. The caller has already pushed a route for the detail, so showing the
    // master here is the whole job.
    if (!Breakpoints.usesMasterDetail(layout)) return master;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(flex: masterFlex, child: master),
        const VerticalDivider(width: 1),
        Expanded(
          flex: detailFlex,
          child: hasSelection ? detail : (emptyDetail ?? const _NoSelection()),
        ),
      ],
    );
  }
}

class _NoSelection extends StatelessWidget {
  const _NoSelection();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.touch_app_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              MasterDetailScaffold.noSelectionLabel,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
