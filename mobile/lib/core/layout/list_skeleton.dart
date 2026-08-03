/// Skeleton loaders for list-shaped screens (T157, FR-064).
///
/// A skeleton is only worth showing when the real layout is **predictable** — same row height,
/// same number of visible rows. Where it is not, a skeleton guesses wrong and the content
/// jumps when it arrives, which is worse than the brief blank it replaced.
///
/// `features/catalogue/presentation/skeletons.dart` already covers the two grids. This covers
/// the list screens: order history, wishlist, addresses.
///
/// Note where skeletons are *not* used: the cart and the checkout render from local data, which
/// is available immediately (FR-019) — there is no wait to fill.
library;

import 'package:flutter/material.dart';

/// A neutral block standing in for a line of content.
///
/// Not animated: a shimmer is motion the user did not ask for, and Principle VII's
/// reduce-motion concern applies to loading states too. The colour alone reads as "not content
/// yet" without implying anything is happening that is not.
class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({
    required this.width,
    required this.height,
    super.key,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// A list of placeholder rows matching the real list's shape.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({
    this.rows = 6,
    this.hasSecondLine = true,
    super.key,
  });

  final int rows;
  final bool hasSecondLine;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // FR-064 and Principle VII: a screen reader should hear that content is coming, not read
      // out a set of unlabelled boxes.
      label: 'Loading',
      liveRegion: true,
      excludeSemantics: true,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: rows,
        separatorBuilder: (_, __) => const Divider(height: 24),
        itemBuilder: (BuildContext context, int index) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SkeletonBlock(width: 160, height: 16),
            if (hasSecondLine) ...<Widget>[
              const SizedBox(height: 8),
              const SkeletonBlock(width: 220, height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
