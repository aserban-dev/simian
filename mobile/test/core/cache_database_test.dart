import 'package:dupermarket/core/cache/cache_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

CacheDatabase _memoryDb() => CacheDatabase(NativeDatabase.memory());

final DateTime _fetchedAt = DateTime.utc(2026, 8, 2, 12);

CachedProductsCompanion _product(String id, {int position = 0, String? category}) =>
    CachedProductsCompanion.insert(
      id: id,
      title: 'Product $id',
      priceMinor: 1999,
      currency: 'EUR',
      thumbnailUrl: 'https://cdn/$id.webp',
      thumbnailAlt: 'Product $id',
      ratingAverage: 4.5,
      ratingCount: 10,
      stockStatus: 'in_stock',
      position: position,
      fetchedAt: _fetchedAt,
      categorySlug: Value<String?>(category),
    );

void main() {
  late CacheDatabase db;

  setUp(() => db = _memoryDb());
  tearDown(() async => db.close());

  group('schema', () {
    test('the cache answers relational queries, not just key lookups', () async {
      // Research D7: this is the whole reason Drift was chosen over a key-value store.
      // Serving "category X, sorted by price, page 2" from cache is what FR-057 needs offline.
      await db.batch((Batch b) {
        b.insertAll(db.cachedProducts, <CachedProductsCompanion>[
          _product('a', position: 0, category: 'shoes'),
          _product('b', position: 1, category: 'shoes'),
          _product('c', position: 0, category: 'bags'),
        ]);
      });

      final rows = await (db.select(db.cachedProducts)
            ..where(($CachedProductsTable t) => t.categorySlug.equals('shoes'))
            ..orderBy(<OrderClauseGenerator<$CachedProductsTable>>[
              ($CachedProductsTable t) => OrderingTerm.asc(t.position),
            ]))
          .get();

      expect(rows.map((CachedProduct r) => r.id), <String>['a', 'b']);
    });

    test('FR-002: cached pages keep the order the server returned', () async {
      await db.batch((Batch b) {
        b.insertAll(db.cachedProducts, <CachedProductsCompanion>[
          _product('third', position: 2),
          _product('first', position: 0),
          _product('second', position: 1),
        ]);
      });

      final rows = await (db.select(db.cachedProducts)
            ..orderBy(<OrderClauseGenerator<$CachedProductsTable>>[
              ($CachedProductsTable t) => OrderingTerm.asc(t.position),
            ]))
          .get();

      expect(
        rows.map((CachedProduct r) => r.id),
        <String>['first', 'second', 'third'],
        reason: 'replaying a cached list out of order would reshuffle the grid offline',
      );
    });

    test('FR-058: every cached row carries the time it was fetched', () async {
      await db.into(db.cachedProducts).insert(_product('a'));
      final row = await db.select(db.cachedProducts).getSingle();

      // Same *instant*, not the same object: Drift stores DateTime as epoch seconds and
      // hands it back in local time, so a UTC value written comes back local. Both are the
      // same point on the timeline, which is all a TTL comparison needs — but `==` on
      // DateTime compares the flag too, and would fail anywhere except UTC.
      expect(row.fetchedAt.isAtSameMomentAs(_fetchedAt), isTrue);
      expect(row.fetchedAt.toUtc(), _fetchedAt);
    });

    test('re-caching a product replaces it rather than duplicating it', () async {
      await db.into(db.cachedProducts).insert(_product('a'));
      await db
          .into(db.cachedProducts)
          .insertOnConflictUpdate(_product('a', position: 5));

      final rows = await db.select(db.cachedProducts).get();
      expect(rows, hasLength(1));
      expect(rows.single.position, 5);
    });

    test('the category tree survives a round trip with its parent links', () async {
      await db.batch((Batch b) {
        b.insertAll(db.cachedCategories, <CachedCategoriesCompanion>[
          CachedCategoriesCompanion.insert(
            id: 'root',
            slug: 'clothing',
            name: 'Clothing',
            sortOrder: 0,
            fetchedAt: _fetchedAt,
          ),
          CachedCategoriesCompanion.insert(
            id: 'child',
            slug: 'shirts',
            name: 'Shirts',
            sortOrder: 0,
            fetchedAt: _fetchedAt,
            parentId: const Value<String?>('root'),
          ),
        ]);
      });

      final children = await (db.select(db.cachedCategories)
            ..where(($CachedCategoriesTable t) => t.parentId.equals('root')))
          .get();
      expect(children.single.slug, 'shirts');
    });
  });

  group('sign-out and invalidation', () {
    test('FR-016: clearAll empties every table', () async {
      await db.into(db.cachedProducts).insert(_product('a'));
      await db.into(db.cacheEntries).insert(
            CacheEntriesCompanion.insert(key: 'products', fetchedAt: _fetchedAt),
          );

      await db.clearAll();

      expect(await db.select(db.cachedProducts).get(), isEmpty);
      expect(await db.select(db.cacheEntries).get(), isEmpty);
    });

    test('FR-016: sign-out leaves the public catalogue cache in place', () async {
      // The catalogue is public data. Clearing it on sign-out would cost every signed-out
      // user an empty first screen for no privacy gain.
      await db.into(db.cachedProducts).insert(_product('a'));

      await db.clearUserScopedData();

      expect(await db.select(db.cachedProducts).get(), hasLength(1));
    });
  });

  group('version handling', () {
    test('the schema version is declared, so an upgrade path exists at all', () {
      expect(db.schemaVersion, greaterThanOrEqualTo(1));
    });

    test('an incompatible cache is rebuilt rather than migrated', () async {
      // The edge case from spec.md: "the catalogue cache exists but is from an older,
      // incompatible app version". Every row here is re-fetchable, so dropping is the safe
      // answer and migrating is work with no payoff.
      final migrator = db.createMigrator();
      await db.migration.onUpgrade(migrator, 0, db.schemaVersion);

      expect(await db.select(db.cachedProducts).get(), isEmpty);
      // And the tables still exist afterwards — a rebuild, not just a drop.
      await db.into(db.cachedProducts).insert(_product('a'));
      expect(await db.select(db.cachedProducts).get(), hasLength(1));
    });
  });
}
