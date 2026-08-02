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

@DriftDatabase(tables: <Type>[CachedCategories, CachedProducts, CacheEntries])
class CacheDatabase extends _$CacheDatabase {
  CacheDatabase(super.executor);

  /// Bump on **any** schema change. There are no incremental migrations by design.
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) => m.createAll(),
        onUpgrade: (Migrator m, int from, int to) async {
          // FR-057's edge case: a cache written by an older app version. Deserialising it
          // would be guesswork; migrating it would be work with no payoff, because every row
          // here is re-fetchable from the server. So: drop and rebuild.
          for (final TableInfo<Table, Object?> table in allTables) {
            await m.deleteTable(table.actualTableName);
          }
          await m.createAll();
        },
      );

  /// Tables holding data that belongs to the signed-in user, and must not outlive them.
  ///
  /// Order history, addresses, wishlist and cart land with their features (T108, T120) and are
  /// added here — not to [clearUserScopedData], which reads this list. A test asserts that
  /// [allTables] is exactly this list plus [publicTables], so a new table cannot be left
  /// unclassified: it fails the suite until somebody decides which side it is on.
  List<TableInfo<Table, Object?>> get userScopedTables => <TableInfo<Table, Object?>>[];

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
