/// Product list: infinite scroll, filters, sort (FR-002 – FR-005).
///
/// Paging is cursor-driven, so appending a page never reshuffles what is already on screen and
/// never loses scroll position. Filters and sort reset paging, because a cursor minted under one
/// sort is meaningless under another — the backend rejects it, and this avoids the round trip.
library;

import 'package:flutter/material.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_view.dart';
import '../../../core/layout/breakpoints.dart';
import '../../../core/network/api_client.dart';
import '../data/catalogue_repository.dart';
import '../domain/catalogue_models.dart';
import 'product_tile.dart';
import 'skeletons.dart';

@immutable
class ProductFilters {
  const ProductFilters({
    this.minPriceMinor,
    this.maxPriceMinor,
    this.minRating,
    this.sort = ProductSort.newest,
  });

  final int? minPriceMinor;
  final int? maxPriceMinor;
  final double? minRating;
  final ProductSort sort;

  bool get hasAny => minPriceMinor != null || maxPriceMinor != null || minRating != null;

  ProductFilters cleared() => ProductFilters(sort: sort);

  ProductFilters copyWith({
    Object? minPriceMinor = _unset,
    Object? maxPriceMinor = _unset,
    Object? minRating = _unset,
    ProductSort? sort,
  }) =>
      ProductFilters(
        minPriceMinor:
            minPriceMinor == _unset ? this.minPriceMinor : minPriceMinor as int?,
        maxPriceMinor:
            maxPriceMinor == _unset ? this.maxPriceMinor : maxPriceMinor as int?,
        minRating: minRating == _unset ? this.minRating : minRating as double?,
        sort: sort ?? this.sort,
      );

  static const Object _unset = Object();
}

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({
    required this.repository,
    this.categorySlug,
    this.categoryName,
    this.searchQuery,
    this.onProductTap,
    this.imageBuilder = defaultProductImage,
    super.key,
  });

  final CatalogueRepository repository;
  final String? categorySlug;
  final String? categoryName;
  final String? searchQuery;
  final void Function(ProductSummary product)? onProductTap;
  final ProductImageBuilder imageBuilder;

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final ScrollController _scroll = ScrollController();
  final List<ProductSummary> _products = <ProductSummary>[];

  ProductFilters _filters = const ProductFilters();
  String? _cursor;
  bool _hasMore = true;
  bool _loadingFirstPage = true;
  bool _loadingNextPage = false;
  bool _currencyFallback = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    // 600px of runway, so the next page is usually there before the user reaches the end —
    // which is what makes the scroll feel continuous rather than punctuated by spinners.
    final bool nearBottom =
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 600;
    if (nearBottom && _hasMore && !_loadingNextPage && !_loadingFirstPage) {
      _loadNextPage();
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _loadingFirstPage = true;
      _failure = null;
    });

    // Show cached content for this category before the request completes (FR-057).
    if (widget.categorySlug != null && widget.searchQuery == null && !_filters.hasAny) {
      final List<ProductSummary> cached =
          await widget.repository.cachedProductsFor(widget.categorySlug!);
      if (cached.isNotEmpty && mounted) {
        setState(() {
          _products
            ..clear()
            ..addAll(cached);
          _loadingFirstPage = false;
        });
      }
    }

    await _fetch(reset: true);
  }

  Future<void> _loadNextPage() => _fetch(reset: false);

  Future<void> _fetch({required bool reset}) async {
    if (!reset) setState(() => _loadingNextPage = true);

    try {
      final ProductPage page = await widget.repository.fetchProducts(
        categorySlug: widget.categorySlug,
        query: widget.searchQuery,
        minPriceMinor: _filters.minPriceMinor,
        maxPriceMinor: _filters.maxPriceMinor,
        minRating: _filters.minRating,
        sort: _filters.sort,
        cursor: reset ? null : _cursor,
      );
      if (!mounted) return;

      setState(() {
        if (reset) _products.clear();
        _products.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _currencyFallback = page.currencyFallback;
        _loadingFirstPage = false;
        _loadingNextPage = false;
        _failure = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingFirstPage = false;
        _loadingNextPage = false;
        // With products already on screen this becomes an inline retry row rather than an
        // error screen (FR-057, FR-060).
        _failure = e.failure;
      });
    }
  }

  void _applyFilters(ProductFilters filters) {
    setState(() {
      _filters = filters;
      _cursor = null;
      _hasMore = true;
    });
    // A cursor from the previous sort would be rejected; restart paging instead (FR-002).
    _fetch(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName ?? widget.searchQuery ?? 'Products'),
        actions: <Widget>[
          PopupMenuButton<ProductSort>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort),
            initialValue: _filters.sort,
            onSelected: (ProductSort sort) => _applyFilters(_filters.copyWith(sort: sort)),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<ProductSort>>[
              for (final ProductSort sort in ProductSort.values)
                PopupMenuItem<ProductSort>(value: sort, child: Text(sort.label)),
            ],
          ),
        ],
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_loadingFirstPage) return const ProductGridSkeleton();

    if (_products.isEmpty) {
      if (_failure != null) {
        return ListView(children: <Widget>[
          const SizedBox(height: 80),
          FailureView(failure: _failure!, onRetry: _loadFirstPage),
        ]);
      }
      // FR-063: no results is an empty state with a way out, not a blank screen.
      return ListView(children: <Widget>[
        const SizedBox(height: 80),
        EmptyStateView(
          icon: Icons.search_off,
          title: 'Nothing matched that search',
          message: _filters.hasAny
              ? 'Try removing a filter to see more.'
              : 'Try different words, or browse a category instead.',
          actionLabel: _filters.hasAny ? 'Clear filters' : 'Back to browsing',
          onAction: () {
            if (_filters.hasAny) {
              _applyFilters(_filters.cleared());
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
      ]);
    }

    final int columns = Breakpoints.productColumns(Breakpoints.of(context));

    return Column(
      children: <Widget>[
        if (_currencyFallback)
          // FR-052: say why the symbol is not the one they picked.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              "Prices shown in the shop's base currency — we don't have a rate for yours yet.",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (_filters.hasAny) _ActiveFilterChips(filters: _filters, onChanged: _applyFilters),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadFirstPage,
            child: GridView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 16,
                childAspectRatio: 0.62,
              ),
              itemCount: _products.length + (_loadingNextPage || _failure != null ? 1 : 0),
              itemBuilder: (BuildContext context, int index) {
                if (index >= _products.length) {
                  return _failure != null
                      ? Center(
                          child: TextButton(
                            onPressed: _loadNextPage,
                            child: const Text('Retry'),
                          ),
                        )
                      : const Center(child: CircularProgressIndicator());
                }
                final ProductSummary product = _products[index];
                return ProductTile(
                  product: product,
                  imageBuilder: widget.imageBuilder,
                  onTap: () => widget.onProductTap?.call(product),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// FR-004: applied filters stay visible and are individually removable.
class _ActiveFilterChips extends StatelessWidget {
  const _ActiveFilterChips({required this.filters, required this.onChanged});

  final ProductFilters filters;
  final void Function(ProductFilters) onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Wrap(
          spacing: 8,
          children: <Widget>[
            if (filters.minPriceMinor != null)
              InputChip(
                label: Text('Min ${filters.minPriceMinor! ~/ 100}'),
                onDeleted: () => onChanged(filters.copyWith(minPriceMinor: null)),
              ),
            if (filters.maxPriceMinor != null)
              InputChip(
                label: Text('Max ${filters.maxPriceMinor! ~/ 100}'),
                onDeleted: () => onChanged(filters.copyWith(maxPriceMinor: null)),
              ),
            if (filters.minRating != null)
              InputChip(
                label: Text('${filters.minRating!.toStringAsFixed(0)}★ and up'),
                onDeleted: () => onChanged(filters.copyWith(minRating: null)),
              ),
          ],
        ),
      ),
    );
  }
}
