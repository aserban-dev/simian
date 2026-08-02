/// The on-device cache.
///
/// Research D7 chose a relational store over key-value because the cache has to answer
/// *queries*, not just fetch by key: "products in category X, sorted by price, page 2" has to be
/// servable from cache for FR-057 to hold offline. That is a relational question.
///
/// Two rules live in the schema itself:
///
/// * **Every cached row carries `fetchedAt`.** FR-058 needs a freshness window, and a TTL that
///   is not stored per row cannot be evaluated per row.
/// * **A schema version bump rebuilds rather than migrates** (see [MigrationStrategy] below).
///   The "cache from an older app version" edge case has exactly one safe answer: throw it away.
///   Cached data is by definition re-fetchable, so a failed migration would be self-inflicted.
library;

import 'package:drift/drift.dart';

part 'cache_database.g.dart';

/// Cached category rows. Flat, with `parentId` — the tree is rebuilt on read, same as the API.
class CachedCategories extends Table {
  TextColumn get id => text()();
  TextColumn get slug => text()();
  TextColumn get name => text()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get parentId => text().nullable()();
  IntColumn get sortOrder => integer()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Cached product summaries.
///
/// Money is stored as minor units (research D4). `currency` is stored alongside because a
/// cached price is only meaningful with the currency it was converted into.
class CachedProducts extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  IntColumn get priceMinor => integer()();
  TextColumn get currency => text()();
  IntColumn get originalPriceMinor => integer().nullable()();
  TextColumn get thumbnailUrl => text()();
  TextColumn get thumbnailAlt => text()();
  RealColumn get ratingAverage => real()();
  IntColumn get ratingCount => integer()();
  TextColumn get stockStatus => text()();

  /// The category page this row was fetched for, so a cached list can be replayed offline.
  TextColumn get categorySlug => text().nullable()();

  /// Position within that list, so cache-served pages keep the server's order (FR-002).
  IntColumn get position => integer()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// When each logical collection was last refreshed, for TTL evaluation (FR-058).
class CacheEntries extends Table {
  TextColumn get key => text()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{key};
}

/// The cart (FR-018, FR-019).
///
/// Local-authoritative and stored, not cached: the rows here *are* the cart, so unlike every
/// other table in this file they are not re-fetchable from the server. That is why the cart is
/// mutable with no connection and why it carries its own price and title snapshots — an offline
/// cart still has to show a running subtotal (FR-020).
///
/// `unitPriceMinor` and `currency` are what the price was when the line was added. They are
/// refreshed from the catalogue when it is reachable, never guessed.
class CartLines extends Table {
  TextColumn get productId => text()();
  IntColumn get quantity => integer()();

  TextColumn get title => text()();
  IntColumn get unitPriceMinor => integer()();
  TextColumn get currency => text()();
  TextColumn get thumbnailUrl => text()();

  /// Mirrors the catalogue's stock status so an unavailable line can be flagged and excluded
  /// from the total without a network round trip (FR-021, FR-078).
  TextColumn get stockStatus => text().withDefault(const Constant('in_stock'))();

  /// True once the catalogue reports the product gone entirely (FR-021).
  BoolColumn get withdrawn => boolean().withDefault(const Constant(false))();

  DateTimeColumn get addedAt => dateTime()();

  /// One line per product — adding the same product again changes the quantity rather than
  /// creating a second line.
  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{productId};
}

@DriftDatabase(tables: <Type>[CachedCategories, CachedProducts, CacheEntries, CartLines])
class CacheDatabase extends _$CacheDatabase {
  CacheDatabase(super.executor);

  /// Bump on **any** schema change. There are no incremental migrations by design.
  ///
  /// 2: added `cart_lines` (US3).
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) => m.createAll(),
        onUpgrade: (Migrator m, int from, int to) async {
          // FR-057's edge case: data written by an older app version. For the *cached* tables,
          // deserialising it would be guesswork and migrating it would be work with no payoff,
          // because every row is re-fetchable from the server. So those are dropped and rebuilt.
          //
          // The cart is not dropped, and must never be: it is local-authoritative (FR-019), so
          // there is nowhere to re-fetch it from. Throwing it away on an app update would delete
          // something the user created. `createAll` adds any table that does not exist yet, so
          // arriving here from schema 1 is what creates `cart_lines`.
          for (final TableInfo<Table, Object?> table in publicTables) {
            await m.deleteTable(table.actualTableName);
          }
          await m.createAll();
        },
      );

  /// Tables holding data that belongs to the signed-in user, and must not outlive them.
  ///
  /// Order history, addresses and wishlist land with their features (T108, T120) and are added
  /// here — not to [clearUserScopedData], which reads this list. A test asserts that
  /// [allTables] is exactly this list plus [publicTables], so a new table cannot be left
  /// unclassified: it fails the suite until somebody decides which side it is on.
  List<TableInfo<Table, Object?>> get userScopedTables => <TableInfo<Table, Object?>>[
        cartLines,
      ];

  /// Tables holding public data, which survives sign-out.
  ///
  /// Keeping the catalogue is what lets a signed-out user still get an instant first screen
  /// (FR-016 permits it explicitly, and Principle VI is the reason to want it).
  List<TableInfo<Table, Object?>> get publicTables => <TableInfo<Table, Object?>>[
        cachedCategories,
        cachedProducts,
        cacheEntries,
      ];

  /// Clears user-scoped caches on sign-out (FR-016).
  Future<void> clearUserScopedData() async {
    for (final TableInfo<Table, Object?> table in userScopedTables) {
      await delete(table).go();
    }
  }

  /// Wipes everything, including the public catalogue. Used by the TTL rebuild path.
  Future<void> clearAll() async {
    for (final TableInfo<Table, Object?> table in allTables) {
      await delete(table).go();
    }
  }
}
