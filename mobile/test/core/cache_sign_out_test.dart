/// Sign-out and the on-device cache (T063, T068, FR-016).
///
/// "Clear all user-scoped local data … MAY retain the public catalogue cache" is two assertions,
/// and the second is the one that decays silently: every feature that lands from here on adds a
/// table, and any one of them can be forgotten at the sign-out call site.
///
/// So the classification is asserted rather than the enumeration. [CacheDatabase.allTables] must
/// equal the user-scoped set plus the public set, which makes a new table a **compile-green,
/// test-red** event until somebody decides which side it belongs on.
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:dupermarket/core/cache/cache_database.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _fetchedAt = DateTime.utc(2026, 8, 2, 12);

CachedProductsCompanion _product(String id) => CachedProductsCompanion.insert(
      id: id,
      title: 'Product $id',
      priceMinor: 1999,
      currency: 'EUR',
      thumbnailUrl: 'https://cdn/$id.webp',
      thumbnailAlt: 'Product $id',
      ratingAverage: 4.5,
      ratingCount: 10,
      stockStatus: 'in_stock',
      position: 0,
      fetchedAt: _fetchedAt,
    );

CachedCategoriesCompanion _category(String id) => CachedCategoriesCompanion.insert(
      id: id,
      slug: 'slug-$id',
      name: 'Category $id',
      sortOrder: 0,
      fetchedAt: _fetchedAt,
    );

void main() {
  late CacheDatabase db;

  setUp(() => db = CacheDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  group('the catalogue survives sign-out (FR-016)', () {
    test('cached products are still there afterwards', () async {
      await db.into(db.cachedProducts).insert(_product('a'));

      await db.clearUserScopedData();

      expect(await db.select(db.cachedProducts).get(), hasLength(1));
    });

    test('cached categories are still there afterwards', () async {
      await db.into(db.cachedCategories).insert(_category('c'));

      await db.clearUserScopedData();

      expect(await db.select(db.cachedCategories).get(), hasLength(1));
    });

    test('freshness bookkeeping survives, so the catalogue is not refetched needlessly', () async {
      await db.into(db.cacheEntries).insert(
            CacheEntriesCompanion.insert(key: 'categories', fetchedAt: _fetchedAt),
          );

      await db.clearUserScopedData();

      expect(await db.select(db.cacheEntries).get(), hasLength(1));
    });
  });

  group('user-scoped data is cleared', () {
    test('every user-scoped table is emptied', () async {
      // Vacuous while the set is empty, and deliberately so: it becomes the real assertion the
      // moment orders (T108) or addresses/wishlist (T120) are classified as user-scoped.
      await db.clearUserScopedData();

      for (final TableInfo<Table, Object?> table in db.userScopedTables) {
        final int remaining = await db.select(table).get().then((List<Object?> r) => r.length);
        expect(remaining, 0, reason: '${table.actualTableName} survived sign-out');
      }
    });

    test('clearAll still wipes the catalogue too, for the TTL rebuild path', () async {
      await db.into(db.cachedProducts).insert(_product('a'));
      await db.into(db.cachedCategories).insert(_category('c'));

      await db.clearAll();

      expect(await db.select(db.cachedProducts).get(), isEmpty);
      expect(await db.select(db.cachedCategories).get(), isEmpty);
    });
  });

  group('no table can be forgotten at the sign-out call site', () {
    test('every table is classified as either user-scoped or public', () {
      final Set<String> classified = <String>{
        for (final TableInfo<Table, Object?> t in db.userScopedTables) t.actualTableName,
        for (final TableInfo<Table, Object?> t in db.publicTables) t.actualTableName,
      };
      final Set<String> all = <String>{
        for (final TableInfo<Table, Object?> t in db.allTables) t.actualTableName,
      };

      expect(
        all.difference(classified),
        isEmpty,
        reason: 'unclassified tables would silently survive sign-out — see FR-016',
      );
    });

    test('no table is claimed by both sides', () {
      final Set<String> userScoped = <String>{
        for (final TableInfo<Table, Object?> t in db.userScopedTables) t.actualTableName,
      };
      final Set<String> public = <String>{
        for (final TableInfo<Table, Object?> t in db.publicTables) t.actualTableName,
      };

      expect(userScoped.intersection(public), isEmpty);
    });

    test('the catalogue tables are on the public side', () {
      final Set<String> public = <String>{
        for (final TableInfo<Table, Object?> t in db.publicTables) t.actualTableName,
      };

      expect(public, containsAll(<String>['cached_products', 'cached_categories']));
    });
  });
}
