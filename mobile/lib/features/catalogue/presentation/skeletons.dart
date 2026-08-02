/// Skeleton loaders.
///
/// FR-064: where the resulting layout is predictable, show its shape rather than a spinner.
/// A grid of grey tiles tells the user what is coming; a centred spinner does not.
///
/// Only ever shown on a cold start — with cached content available, FR-057 requires the content
/// itself, not a skeleton over the top of it.
library;

import 'package:flutter/material.dart';

import '../../../core/layout/breakpoints.dart';

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({this.height, this.width, this.aspectRatio});

  final double? height;
  final double? width;
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    final Widget box = DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SizedBox(height: height, width: width),
    );
    return aspectRatio == null ? box : AspectRatio(aspectRatio: aspectRatio!, child: box);
  }
}

class CategoryGridSkeleton extends StatelessWidget {
  const CategoryGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final int columns = Breakpoints.productColumns(Breakpoints.of(context));
    return Semantics(
      // FR-068: announced as a loading state rather than as a screenful of blank boxes.
      label: 'Loading categories',
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        itemCount: columns * 3,
        itemBuilder: (_, __) => const _SkeletonBox(),
      ),
    );
  }
}

class ProductGridSkeleton extends StatelessWidget {
  const ProductGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final int columns = Breakpoints.productColumns(Breakpoints.of(context));
    return Semantics(
      label: 'Loading products',
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
          childAspectRatio: 0.62,
        ),
        itemCount: columns * 3,
        itemBuilder: (_, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _SkeletonBox(aspectRatio: 1),
            const SizedBox(height: 8),
            const _SkeletonBox(height: 12),
            const SizedBox(height: 6),
            _SkeletonBox(height: 12, width: MediaQuery.sizeOf(context).width * 0.1),
          ],
        ),
      ),
    );
  }
}
