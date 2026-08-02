/// Home: the top-level category grid (FR-001).
///
/// Renders from cache before any request completes (FR-057), shows skeletons only on a cold
/// start (FR-064), and keeps content on screen when a refresh fails (FR-060).
library;

import 'package:flutter/material.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_view.dart';
import '../../../core/layout/breakpoints.dart';
import '../../../core/network/api_client.dart';
import '../data/catalogue_repository.dart';
import '../domain/catalogue_models.dart';
import 'skeletons.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.repository, this.onCategoryTap, super.key});

  final CatalogueRepository repository;
  final void Function(Category category)? onCategoryTap;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Snapshot<List<Category>>? _snapshot;
  AppFailure? _fatalFailure;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool userRequested = false}) async {
    setState(() {
      _loading = _snapshot == null;
      _fatalFailure = null;
    });
    try {
      await for (final Snapshot<List<Category>> snapshot
          in widget.repository.watchCategories(userRequested: userRequested)) {
        if (!mounted) return;
        // Each emission replaces the last: cache first, then fresh (FR-057).
        setState(() {
          _snapshot = snapshot;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      // Only reachable with an empty cache — the repository keeps content on screen
      // otherwise. So this is the cold-start failure, and it owns the whole screen.
      setState(() {
        _fatalFailure = e.failure;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DuperMarket')),
      body: SafeArea(child: RefreshIndicator(onRefresh: () => _load(userRequested: true), child: _body())),
    );
  }

  Widget _body() {
    if (_loading) return const CategoryGridSkeleton();

    if (_fatalFailure != null) {
      return ListView(
        children: <Widget>[
          const SizedBox(height: 80),
          FailureView(failure: _fatalFailure!, onRetry: _load),
        ],
      );
    }

    final List<Category> categories = _snapshot?.data ?? const <Category>[];
    if (categories.isEmpty) {
      return ListView(
        children: <Widget>[
          const SizedBox(height: 80),
          EmptyStateView(
            icon: Icons.storefront_outlined,
            title: 'Nothing to browse yet',
            message: 'The shop has no categories right now. Try again in a moment.',
            actionLabel: 'Refresh',
            onAction: () => _load(userRequested: true),
          ),
        ],
      );
    }

    final int columns = Breakpoints.productColumns(Breakpoints.of(context));

    return Column(
      children: <Widget>[
        // FR-060: a failed refresh over usable content is a notice, not a takeover.
        if (_snapshot?.isStale ?? false)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _StaleNotice(),
          ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: categories.length,
            itemBuilder: (BuildContext context, int index) => _CategoryCard(
              category: categories[index],
              onTap: () => widget.onCategoryTap?.call(categories[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _StaleNotice extends StatelessWidget {
  const _StaleNotice();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: Row(
        children: <Widget>[
          Icon(Icons.history_toggle_off, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              "Showing what we had — we couldn't refresh just now",
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, this.onTap});

  final Category category;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Semantics(
      button: true,
      label: 'Category ${category.name}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: category.imageUrl == null || category.imageUrl!.isEmpty
                    ? ColoredBox(color: theme.colorScheme.surfaceContainerHighest)
                    : Image.network(
                        category.imageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        // FR-061 again: one category image failing is not a broken home screen.
                        errorBuilder: (_, __, ___) =>
                            ColoredBox(color: theme.colorScheme.surfaceContainerHighest),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              category.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
