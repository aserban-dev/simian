// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cache_database.dart';

// ignore_for_file: type=lint
class $CachedCategoriesTable extends CachedCategories
    with TableInfo<$CachedCategoriesTable, CachedCategory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedCategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _slugMeta = const VerificationMeta('slug');
  @override
  late final GeneratedColumn<String> slug = GeneratedColumn<String>(
      'slug', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _imageUrlMeta =
      const VerificationMeta('imageUrl');
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
      'image_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _parentIdMeta =
      const VerificationMeta('parentId');
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
      'parent_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _fetchedAtMeta =
      const VerificationMeta('fetchedAt');
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
      'fetched_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, slug, name, imageUrl, parentId, sortOrder, fetchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_categories';
  @override
  VerificationContext validateIntegrity(Insertable<CachedCategory> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('slug')) {
      context.handle(
          _slugMeta, slug.isAcceptableOrUnknown(data['slug']!, _slugMeta));
    } else if (isInserting) {
      context.missing(_slugMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('image_url')) {
      context.handle(_imageUrlMeta,
          imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta));
    }
    if (data.containsKey('parent_id')) {
      context.handle(_parentIdMeta,
          parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(_fetchedAtMeta,
          fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta));
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedCategory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedCategory(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      slug: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}slug'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      imageUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_url']),
      parentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}parent_id']),
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      fetchedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}fetched_at'])!,
    );
  }

  @override
  $CachedCategoriesTable createAlias(String alias) {
    return $CachedCategoriesTable(attachedDatabase, alias);
  }
}

class CachedCategory extends DataClass implements Insertable<CachedCategory> {
  final String id;
  final String slug;
  final String name;
  final String? imageUrl;
  final String? parentId;
  final int sortOrder;
  final DateTime fetchedAt;
  const CachedCategory(
      {required this.id,
      required this.slug,
      required this.name,
      this.imageUrl,
      this.parentId,
      required this.sortOrder,
      required this.fetchedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['slug'] = Variable<String>(slug);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  CachedCategoriesCompanion toCompanion(bool nullToAbsent) {
    return CachedCategoriesCompanion(
      id: Value(id),
      slug: Value(slug),
      name: Value(name),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      sortOrder: Value(sortOrder),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory CachedCategory.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedCategory(
      id: serializer.fromJson<String>(json['id']),
      slug: serializer.fromJson<String>(json['slug']),
      name: serializer.fromJson<String>(json['name']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'slug': serializer.toJson<String>(slug),
      'name': serializer.toJson<String>(name),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'parentId': serializer.toJson<String?>(parentId),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  CachedCategory copyWith(
          {String? id,
          String? slug,
          String? name,
          Value<String?> imageUrl = const Value.absent(),
          Value<String?> parentId = const Value.absent(),
          int? sortOrder,
          DateTime? fetchedAt}) =>
      CachedCategory(
        id: id ?? this.id,
        slug: slug ?? this.slug,
        name: name ?? this.name,
        imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
        parentId: parentId.present ? parentId.value : this.parentId,
        sortOrder: sortOrder ?? this.sortOrder,
        fetchedAt: fetchedAt ?? this.fetchedAt,
      );
  CachedCategory copyWithCompanion(CachedCategoriesCompanion data) {
    return CachedCategory(
      id: data.id.present ? data.id.value : this.id,
      slug: data.slug.present ? data.slug.value : this.slug,
      name: data.name.present ? data.name.value : this.name,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedCategory(')
          ..write('id: $id, ')
          ..write('slug: $slug, ')
          ..write('name: $name, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('parentId: $parentId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, slug, name, imageUrl, parentId, sortOrder, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedCategory &&
          other.id == this.id &&
          other.slug == this.slug &&
          other.name == this.name &&
          other.imageUrl == this.imageUrl &&
          other.parentId == this.parentId &&
          other.sortOrder == this.sortOrder &&
          other.fetchedAt == this.fetchedAt);
}

class CachedCategoriesCompanion extends UpdateCompanion<CachedCategory> {
  final Value<String> id;
  final Value<String> slug;
  final Value<String> name;
  final Value<String?> imageUrl;
  final Value<String?> parentId;
  final Value<int> sortOrder;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const CachedCategoriesCompanion({
    this.id = const Value.absent(),
    this.slug = const Value.absent(),
    this.name = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.parentId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedCategoriesCompanion.insert({
    required String id,
    required String slug,
    required String name,
    this.imageUrl = const Value.absent(),
    this.parentId = const Value.absent(),
    required int sortOrder,
    required DateTime fetchedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        slug = Value(slug),
        name = Value(name),
        sortOrder = Value(sortOrder),
        fetchedAt = Value(fetchedAt);
  static Insertable<CachedCategory> custom({
    Expression<String>? id,
    Expression<String>? slug,
    Expression<String>? name,
    Expression<String>? imageUrl,
    Expression<String>? parentId,
    Expression<int>? sortOrder,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (slug != null) 'slug': slug,
      if (name != null) 'name': name,
      if (imageUrl != null) 'image_url': imageUrl,
      if (parentId != null) 'parent_id': parentId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedCategoriesCompanion copyWith(
      {Value<String>? id,
      Value<String>? slug,
      Value<String>? name,
      Value<String?>? imageUrl,
      Value<String?>? parentId,
      Value<int>? sortOrder,
      Value<DateTime>? fetchedAt,
      Value<int>? rowid}) {
    return CachedCategoriesCompanion(
      id: id ?? this.id,
      slug: slug ?? this.slug,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      parentId: parentId ?? this.parentId,
      sortOrder: sortOrder ?? this.sortOrder,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (slug.present) {
      map['slug'] = Variable<String>(slug.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedCategoriesCompanion(')
          ..write('id: $id, ')
          ..write('slug: $slug, ')
          ..write('name: $name, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('parentId: $parentId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedProductsTable extends CachedProducts
    with TableInfo<$CachedProductsTable, CachedProduct> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedProductsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _priceMinorMeta =
      const VerificationMeta('priceMinor');
  @override
  late final GeneratedColumn<int> priceMinor = GeneratedColumn<int>(
      'price_minor', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _originalPriceMinorMeta =
      const VerificationMeta('originalPriceMinor');
  @override
  late final GeneratedColumn<int> originalPriceMinor = GeneratedColumn<int>(
      'original_price_minor', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _thumbnailUrlMeta =
      const VerificationMeta('thumbnailUrl');
  @override
  late final GeneratedColumn<String> thumbnailUrl = GeneratedColumn<String>(
      'thumbnail_url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _thumbnailAltMeta =
      const VerificationMeta('thumbnailAlt');
  @override
  late final GeneratedColumn<String> thumbnailAlt = GeneratedColumn<String>(
      'thumbnail_alt', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ratingAverageMeta =
      const VerificationMeta('ratingAverage');
  @override
  late final GeneratedColumn<double> ratingAverage = GeneratedColumn<double>(
      'rating_average', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _ratingCountMeta =
      const VerificationMeta('ratingCount');
  @override
  late final GeneratedColumn<int> ratingCount = GeneratedColumn<int>(
      'rating_count', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _stockStatusMeta =
      const VerificationMeta('stockStatus');
  @override
  late final GeneratedColumn<String> stockStatus = GeneratedColumn<String>(
      'stock_status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _categorySlugMeta =
      const VerificationMeta('categorySlug');
  @override
  late final GeneratedColumn<String> categorySlug = GeneratedColumn<String>(
      'category_slug', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _positionMeta =
      const VerificationMeta('position');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
      'position', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _fetchedAtMeta =
      const VerificationMeta('fetchedAt');
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
      'fetched_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        title,
        priceMinor,
        currency,
        originalPriceMinor,
        thumbnailUrl,
        thumbnailAlt,
        ratingAverage,
        ratingCount,
        stockStatus,
        categorySlug,
        position,
        fetchedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_products';
  @override
  VerificationContext validateIntegrity(Insertable<CachedProduct> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('price_minor')) {
      context.handle(
          _priceMinorMeta,
          priceMinor.isAcceptableOrUnknown(
              data['price_minor']!, _priceMinorMeta));
    } else if (isInserting) {
      context.missing(_priceMinorMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('original_price_minor')) {
      context.handle(
          _originalPriceMinorMeta,
          originalPriceMinor.isAcceptableOrUnknown(
              data['original_price_minor']!, _originalPriceMinorMeta));
    }
    if (data.containsKey('thumbnail_url')) {
      context.handle(
          _thumbnailUrlMeta,
          thumbnailUrl.isAcceptableOrUnknown(
              data['thumbnail_url']!, _thumbnailUrlMeta));
    } else if (isInserting) {
      context.missing(_thumbnailUrlMeta);
    }
    if (data.containsKey('thumbnail_alt')) {
      context.handle(
          _thumbnailAltMeta,
          thumbnailAlt.isAcceptableOrUnknown(
              data['thumbnail_alt']!, _thumbnailAltMeta));
    } else if (isInserting) {
      context.missing(_thumbnailAltMeta);
    }
    if (data.containsKey('rating_average')) {
      context.handle(
          _ratingAverageMeta,
          ratingAverage.isAcceptableOrUnknown(
              data['rating_average']!, _ratingAverageMeta));
    } else if (isInserting) {
      context.missing(_ratingAverageMeta);
    }
    if (data.containsKey('rating_count')) {
      context.handle(
          _ratingCountMeta,
          ratingCount.isAcceptableOrUnknown(
              data['rating_count']!, _ratingCountMeta));
    } else if (isInserting) {
      context.missing(_ratingCountMeta);
    }
    if (data.containsKey('stock_status')) {
      context.handle(
          _stockStatusMeta,
          stockStatus.isAcceptableOrUnknown(
              data['stock_status']!, _stockStatusMeta));
    } else if (isInserting) {
      context.missing(_stockStatusMeta);
    }
    if (data.containsKey('category_slug')) {
      context.handle(
          _categorySlugMeta,
          categorySlug.isAcceptableOrUnknown(
              data['category_slug']!, _categorySlugMeta));
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta,
          position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(_fetchedAtMeta,
          fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta));
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedProduct map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedProduct(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      priceMinor: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}price_minor'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      originalPriceMinor: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}original_price_minor']),
      thumbnailUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}thumbnail_url'])!,
      thumbnailAlt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}thumbnail_alt'])!,
      ratingAverage: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}rating_average'])!,
      ratingCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}rating_count'])!,
      stockStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}stock_status'])!,
      categorySlug: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category_slug']),
      position: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position'])!,
      fetchedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}fetched_at'])!,
    );
  }

  @override
  $CachedProductsTable createAlias(String alias) {
    return $CachedProductsTable(attachedDatabase, alias);
  }
}

class CachedProduct extends DataClass implements Insertable<CachedProduct> {
  final String id;
  final String title;
  final int priceMinor;
  final String currency;
  final int? originalPriceMinor;
  final String thumbnailUrl;
  final String thumbnailAlt;
  final double ratingAverage;
  final int ratingCount;
  final String stockStatus;

  /// The category page this row was fetched for, so a cached list can be replayed offline.
  final String? categorySlug;

  /// Position within that list, so cache-served pages keep the server's order (FR-002).
  final int position;
  final DateTime fetchedAt;
  const CachedProduct(
      {required this.id,
      required this.title,
      required this.priceMinor,
      required this.currency,
      this.originalPriceMinor,
      required this.thumbnailUrl,
      required this.thumbnailAlt,
      required this.ratingAverage,
      required this.ratingCount,
      required this.stockStatus,
      this.categorySlug,
      required this.position,
      required this.fetchedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['price_minor'] = Variable<int>(priceMinor);
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || originalPriceMinor != null) {
      map['original_price_minor'] = Variable<int>(originalPriceMinor);
    }
    map['thumbnail_url'] = Variable<String>(thumbnailUrl);
    map['thumbnail_alt'] = Variable<String>(thumbnailAlt);
    map['rating_average'] = Variable<double>(ratingAverage);
    map['rating_count'] = Variable<int>(ratingCount);
    map['stock_status'] = Variable<String>(stockStatus);
    if (!nullToAbsent || categorySlug != null) {
      map['category_slug'] = Variable<String>(categorySlug);
    }
    map['position'] = Variable<int>(position);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  CachedProductsCompanion toCompanion(bool nullToAbsent) {
    return CachedProductsCompanion(
      id: Value(id),
      title: Value(title),
      priceMinor: Value(priceMinor),
      currency: Value(currency),
      originalPriceMinor: originalPriceMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(originalPriceMinor),
      thumbnailUrl: Value(thumbnailUrl),
      thumbnailAlt: Value(thumbnailAlt),
      ratingAverage: Value(ratingAverage),
      ratingCount: Value(ratingCount),
      stockStatus: Value(stockStatus),
      categorySlug: categorySlug == null && nullToAbsent
          ? const Value.absent()
          : Value(categorySlug),
      position: Value(position),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory CachedProduct.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedProduct(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      priceMinor: serializer.fromJson<int>(json['priceMinor']),
      currency: serializer.fromJson<String>(json['currency']),
      originalPriceMinor: serializer.fromJson<int?>(json['originalPriceMinor']),
      thumbnailUrl: serializer.fromJson<String>(json['thumbnailUrl']),
      thumbnailAlt: serializer.fromJson<String>(json['thumbnailAlt']),
      ratingAverage: serializer.fromJson<double>(json['ratingAverage']),
      ratingCount: serializer.fromJson<int>(json['ratingCount']),
      stockStatus: serializer.fromJson<String>(json['stockStatus']),
      categorySlug: serializer.fromJson<String?>(json['categorySlug']),
      position: serializer.fromJson<int>(json['position']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'priceMinor': serializer.toJson<int>(priceMinor),
      'currency': serializer.toJson<String>(currency),
      'originalPriceMinor': serializer.toJson<int?>(originalPriceMinor),
      'thumbnailUrl': serializer.toJson<String>(thumbnailUrl),
      'thumbnailAlt': serializer.toJson<String>(thumbnailAlt),
      'ratingAverage': serializer.toJson<double>(ratingAverage),
      'ratingCount': serializer.toJson<int>(ratingCount),
      'stockStatus': serializer.toJson<String>(stockStatus),
      'categorySlug': serializer.toJson<String?>(categorySlug),
      'position': serializer.toJson<int>(position),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  CachedProduct copyWith(
          {String? id,
          String? title,
          int? priceMinor,
          String? currency,
          Value<int?> originalPriceMinor = const Value.absent(),
          String? thumbnailUrl,
          String? thumbnailAlt,
          double? ratingAverage,
          int? ratingCount,
          String? stockStatus,
          Value<String?> categorySlug = const Value.absent(),
          int? position,
          DateTime? fetchedAt}) =>
      CachedProduct(
        id: id ?? this.id,
        title: title ?? this.title,
        priceMinor: priceMinor ?? this.priceMinor,
        currency: currency ?? this.currency,
        originalPriceMinor: originalPriceMinor.present
            ? originalPriceMinor.value
            : this.originalPriceMinor,
        thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
        thumbnailAlt: thumbnailAlt ?? this.thumbnailAlt,
        ratingAverage: ratingAverage ?? this.ratingAverage,
        ratingCount: ratingCount ?? this.ratingCount,
        stockStatus: stockStatus ?? this.stockStatus,
        categorySlug:
            categorySlug.present ? categorySlug.value : this.categorySlug,
        position: position ?? this.position,
        fetchedAt: fetchedAt ?? this.fetchedAt,
      );
  CachedProduct copyWithCompanion(CachedProductsCompanion data) {
    return CachedProduct(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      priceMinor:
          data.priceMinor.present ? data.priceMinor.value : this.priceMinor,
      currency: data.currency.present ? data.currency.value : this.currency,
      originalPriceMinor: data.originalPriceMinor.present
          ? data.originalPriceMinor.value
          : this.originalPriceMinor,
      thumbnailUrl: data.thumbnailUrl.present
          ? data.thumbnailUrl.value
          : this.thumbnailUrl,
      thumbnailAlt: data.thumbnailAlt.present
          ? data.thumbnailAlt.value
          : this.thumbnailAlt,
      ratingAverage: data.ratingAverage.present
          ? data.ratingAverage.value
          : this.ratingAverage,
      ratingCount:
          data.ratingCount.present ? data.ratingCount.value : this.ratingCount,
      stockStatus:
          data.stockStatus.present ? data.stockStatus.value : this.stockStatus,
      categorySlug: data.categorySlug.present
          ? data.categorySlug.value
          : this.categorySlug,
      position: data.position.present ? data.position.value : this.position,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedProduct(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('priceMinor: $priceMinor, ')
          ..write('currency: $currency, ')
          ..write('originalPriceMinor: $originalPriceMinor, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('thumbnailAlt: $thumbnailAlt, ')
          ..write('ratingAverage: $ratingAverage, ')
          ..write('ratingCount: $ratingCount, ')
          ..write('stockStatus: $stockStatus, ')
          ..write('categorySlug: $categorySlug, ')
          ..write('position: $position, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      title,
      priceMinor,
      currency,
      originalPriceMinor,
      thumbnailUrl,
      thumbnailAlt,
      ratingAverage,
      ratingCount,
      stockStatus,
      categorySlug,
      position,
      fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedProduct &&
          other.id == this.id &&
          other.title == this.title &&
          other.priceMinor == this.priceMinor &&
          other.currency == this.currency &&
          other.originalPriceMinor == this.originalPriceMinor &&
          other.thumbnailUrl == this.thumbnailUrl &&
          other.thumbnailAlt == this.thumbnailAlt &&
          other.ratingAverage == this.ratingAverage &&
          other.ratingCount == this.ratingCount &&
          other.stockStatus == this.stockStatus &&
          other.categorySlug == this.categorySlug &&
          other.position == this.position &&
          other.fetchedAt == this.fetchedAt);
}

class CachedProductsCompanion extends UpdateCompanion<CachedProduct> {
  final Value<String> id;
  final Value<String> title;
  final Value<int> priceMinor;
  final Value<String> currency;
  final Value<int?> originalPriceMinor;
  final Value<String> thumbnailUrl;
  final Value<String> thumbnailAlt;
  final Value<double> ratingAverage;
  final Value<int> ratingCount;
  final Value<String> stockStatus;
  final Value<String?> categorySlug;
  final Value<int> position;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const CachedProductsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.priceMinor = const Value.absent(),
    this.currency = const Value.absent(),
    this.originalPriceMinor = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.thumbnailAlt = const Value.absent(),
    this.ratingAverage = const Value.absent(),
    this.ratingCount = const Value.absent(),
    this.stockStatus = const Value.absent(),
    this.categorySlug = const Value.absent(),
    this.position = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedProductsCompanion.insert({
    required String id,
    required String title,
    required int priceMinor,
    required String currency,
    this.originalPriceMinor = const Value.absent(),
    required String thumbnailUrl,
    required String thumbnailAlt,
    required double ratingAverage,
    required int ratingCount,
    required String stockStatus,
    this.categorySlug = const Value.absent(),
    required int position,
    required DateTime fetchedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        priceMinor = Value(priceMinor),
        currency = Value(currency),
        thumbnailUrl = Value(thumbnailUrl),
        thumbnailAlt = Value(thumbnailAlt),
        ratingAverage = Value(ratingAverage),
        ratingCount = Value(ratingCount),
        stockStatus = Value(stockStatus),
        position = Value(position),
        fetchedAt = Value(fetchedAt);
  static Insertable<CachedProduct> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<int>? priceMinor,
    Expression<String>? currency,
    Expression<int>? originalPriceMinor,
    Expression<String>? thumbnailUrl,
    Expression<String>? thumbnailAlt,
    Expression<double>? ratingAverage,
    Expression<int>? ratingCount,
    Expression<String>? stockStatus,
    Expression<String>? categorySlug,
    Expression<int>? position,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (priceMinor != null) 'price_minor': priceMinor,
      if (currency != null) 'currency': currency,
      if (originalPriceMinor != null)
        'original_price_minor': originalPriceMinor,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (thumbnailAlt != null) 'thumbnail_alt': thumbnailAlt,
      if (ratingAverage != null) 'rating_average': ratingAverage,
      if (ratingCount != null) 'rating_count': ratingCount,
      if (stockStatus != null) 'stock_status': stockStatus,
      if (categorySlug != null) 'category_slug': categorySlug,
      if (position != null) 'position': position,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedProductsCompanion copyWith(
      {Value<String>? id,
      Value<String>? title,
      Value<int>? priceMinor,
      Value<String>? currency,
      Value<int?>? originalPriceMinor,
      Value<String>? thumbnailUrl,
      Value<String>? thumbnailAlt,
      Value<double>? ratingAverage,
      Value<int>? ratingCount,
      Value<String>? stockStatus,
      Value<String?>? categorySlug,
      Value<int>? position,
      Value<DateTime>? fetchedAt,
      Value<int>? rowid}) {
    return CachedProductsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      priceMinor: priceMinor ?? this.priceMinor,
      currency: currency ?? this.currency,
      originalPriceMinor: originalPriceMinor ?? this.originalPriceMinor,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      thumbnailAlt: thumbnailAlt ?? this.thumbnailAlt,
      ratingAverage: ratingAverage ?? this.ratingAverage,
      ratingCount: ratingCount ?? this.ratingCount,
      stockStatus: stockStatus ?? this.stockStatus,
      categorySlug: categorySlug ?? this.categorySlug,
      position: position ?? this.position,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (priceMinor.present) {
      map['price_minor'] = Variable<int>(priceMinor.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (originalPriceMinor.present) {
      map['original_price_minor'] = Variable<int>(originalPriceMinor.value);
    }
    if (thumbnailUrl.present) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl.value);
    }
    if (thumbnailAlt.present) {
      map['thumbnail_alt'] = Variable<String>(thumbnailAlt.value);
    }
    if (ratingAverage.present) {
      map['rating_average'] = Variable<double>(ratingAverage.value);
    }
    if (ratingCount.present) {
      map['rating_count'] = Variable<int>(ratingCount.value);
    }
    if (stockStatus.present) {
      map['stock_status'] = Variable<String>(stockStatus.value);
    }
    if (categorySlug.present) {
      map['category_slug'] = Variable<String>(categorySlug.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedProductsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('priceMinor: $priceMinor, ')
          ..write('currency: $currency, ')
          ..write('originalPriceMinor: $originalPriceMinor, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('thumbnailAlt: $thumbnailAlt, ')
          ..write('ratingAverage: $ratingAverage, ')
          ..write('ratingCount: $ratingCount, ')
          ..write('stockStatus: $stockStatus, ')
          ..write('categorySlug: $categorySlug, ')
          ..write('position: $position, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CacheEntriesTable extends CacheEntries
    with TableInfo<$CacheEntriesTable, CacheEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CacheEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _fetchedAtMeta =
      const VerificationMeta('fetchedAt');
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
      'fetched_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, fetchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cache_entries';
  @override
  VerificationContext validateIntegrity(Insertable<CacheEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(_fetchedAtMeta,
          fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta));
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  CacheEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CacheEntry(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      fetchedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}fetched_at'])!,
    );
  }

  @override
  $CacheEntriesTable createAlias(String alias) {
    return $CacheEntriesTable(attachedDatabase, alias);
  }
}

class CacheEntry extends DataClass implements Insertable<CacheEntry> {
  final String key;
  final DateTime fetchedAt;
  const CacheEntry({required this.key, required this.fetchedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  CacheEntriesCompanion toCompanion(bool nullToAbsent) {
    return CacheEntriesCompanion(
      key: Value(key),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory CacheEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CacheEntry(
      key: serializer.fromJson<String>(json['key']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  CacheEntry copyWith({String? key, DateTime? fetchedAt}) => CacheEntry(
        key: key ?? this.key,
        fetchedAt: fetchedAt ?? this.fetchedAt,
      );
  CacheEntry copyWithCompanion(CacheEntriesCompanion data) {
    return CacheEntry(
      key: data.key.present ? data.key.value : this.key,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CacheEntry(')
          ..write('key: $key, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CacheEntry &&
          other.key == this.key &&
          other.fetchedAt == this.fetchedAt);
}

class CacheEntriesCompanion extends UpdateCompanion<CacheEntry> {
  final Value<String> key;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const CacheEntriesCompanion({
    this.key = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CacheEntriesCompanion.insert({
    required String key,
    required DateTime fetchedAt,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        fetchedAt = Value(fetchedAt);
  static Insertable<CacheEntry> custom({
    Expression<String>? key,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CacheEntriesCompanion copyWith(
      {Value<String>? key, Value<DateTime>? fetchedAt, Value<int>? rowid}) {
    return CacheEntriesCompanion(
      key: key ?? this.key,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CacheEntriesCompanion(')
          ..write('key: $key, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CartLinesTable extends CartLines
    with TableInfo<$CartLinesTable, CartLine> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CartLinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _productIdMeta =
      const VerificationMeta('productId');
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
      'product_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _quantityMeta =
      const VerificationMeta('quantity');
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
      'quantity', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _unitPriceMinorMeta =
      const VerificationMeta('unitPriceMinor');
  @override
  late final GeneratedColumn<int> unitPriceMinor = GeneratedColumn<int>(
      'unit_price_minor', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _thumbnailUrlMeta =
      const VerificationMeta('thumbnailUrl');
  @override
  late final GeneratedColumn<String> thumbnailUrl = GeneratedColumn<String>(
      'thumbnail_url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _stockStatusMeta =
      const VerificationMeta('stockStatus');
  @override
  late final GeneratedColumn<String> stockStatus = GeneratedColumn<String>(
      'stock_status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('in_stock'));
  static const VerificationMeta _withdrawnMeta =
      const VerificationMeta('withdrawn');
  @override
  late final GeneratedColumn<bool> withdrawn = GeneratedColumn<bool>(
      'withdrawn', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("withdrawn" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _addedAtMeta =
      const VerificationMeta('addedAt');
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
      'added_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        productId,
        quantity,
        title,
        unitPriceMinor,
        currency,
        thumbnailUrl,
        stockStatus,
        withdrawn,
        addedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cart_lines';
  @override
  VerificationContext validateIntegrity(Insertable<CartLine> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('product_id')) {
      context.handle(_productIdMeta,
          productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta));
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(_quantityMeta,
          quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta));
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('unit_price_minor')) {
      context.handle(
          _unitPriceMinorMeta,
          unitPriceMinor.isAcceptableOrUnknown(
              data['unit_price_minor']!, _unitPriceMinorMeta));
    } else if (isInserting) {
      context.missing(_unitPriceMinorMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('thumbnail_url')) {
      context.handle(
          _thumbnailUrlMeta,
          thumbnailUrl.isAcceptableOrUnknown(
              data['thumbnail_url']!, _thumbnailUrlMeta));
    } else if (isInserting) {
      context.missing(_thumbnailUrlMeta);
    }
    if (data.containsKey('stock_status')) {
      context.handle(
          _stockStatusMeta,
          stockStatus.isAcceptableOrUnknown(
              data['stock_status']!, _stockStatusMeta));
    }
    if (data.containsKey('withdrawn')) {
      context.handle(_withdrawnMeta,
          withdrawn.isAcceptableOrUnknown(data['withdrawn']!, _withdrawnMeta));
    }
    if (data.containsKey('added_at')) {
      context.handle(_addedAtMeta,
          addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta));
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {productId};
  @override
  CartLine map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CartLine(
      productId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}product_id'])!,
      quantity: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}quantity'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      unitPriceMinor: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}unit_price_minor'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      thumbnailUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}thumbnail_url'])!,
      stockStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}stock_status'])!,
      withdrawn: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}withdrawn'])!,
      addedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}added_at'])!,
    );
  }

  @override
  $CartLinesTable createAlias(String alias) {
    return $CartLinesTable(attachedDatabase, alias);
  }
}

class CartLine extends DataClass implements Insertable<CartLine> {
  final String productId;
  final int quantity;
  final String title;
  final int unitPriceMinor;
  final String currency;
  final String thumbnailUrl;

  /// Mirrors the catalogue's stock status so an unavailable line can be flagged and excluded
  /// from the total without a network round trip (FR-021, FR-078).
  final String stockStatus;

  /// True once the catalogue reports the product gone entirely (FR-021).
  final bool withdrawn;
  final DateTime addedAt;
  const CartLine(
      {required this.productId,
      required this.quantity,
      required this.title,
      required this.unitPriceMinor,
      required this.currency,
      required this.thumbnailUrl,
      required this.stockStatus,
      required this.withdrawn,
      required this.addedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['product_id'] = Variable<String>(productId);
    map['quantity'] = Variable<int>(quantity);
    map['title'] = Variable<String>(title);
    map['unit_price_minor'] = Variable<int>(unitPriceMinor);
    map['currency'] = Variable<String>(currency);
    map['thumbnail_url'] = Variable<String>(thumbnailUrl);
    map['stock_status'] = Variable<String>(stockStatus);
    map['withdrawn'] = Variable<bool>(withdrawn);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  CartLinesCompanion toCompanion(bool nullToAbsent) {
    return CartLinesCompanion(
      productId: Value(productId),
      quantity: Value(quantity),
      title: Value(title),
      unitPriceMinor: Value(unitPriceMinor),
      currency: Value(currency),
      thumbnailUrl: Value(thumbnailUrl),
      stockStatus: Value(stockStatus),
      withdrawn: Value(withdrawn),
      addedAt: Value(addedAt),
    );
  }

  factory CartLine.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CartLine(
      productId: serializer.fromJson<String>(json['productId']),
      quantity: serializer.fromJson<int>(json['quantity']),
      title: serializer.fromJson<String>(json['title']),
      unitPriceMinor: serializer.fromJson<int>(json['unitPriceMinor']),
      currency: serializer.fromJson<String>(json['currency']),
      thumbnailUrl: serializer.fromJson<String>(json['thumbnailUrl']),
      stockStatus: serializer.fromJson<String>(json['stockStatus']),
      withdrawn: serializer.fromJson<bool>(json['withdrawn']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'productId': serializer.toJson<String>(productId),
      'quantity': serializer.toJson<int>(quantity),
      'title': serializer.toJson<String>(title),
      'unitPriceMinor': serializer.toJson<int>(unitPriceMinor),
      'currency': serializer.toJson<String>(currency),
      'thumbnailUrl': serializer.toJson<String>(thumbnailUrl),
      'stockStatus': serializer.toJson<String>(stockStatus),
      'withdrawn': serializer.toJson<bool>(withdrawn),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  CartLine copyWith(
          {String? productId,
          int? quantity,
          String? title,
          int? unitPriceMinor,
          String? currency,
          String? thumbnailUrl,
          String? stockStatus,
          bool? withdrawn,
          DateTime? addedAt}) =>
      CartLine(
        productId: productId ?? this.productId,
        quantity: quantity ?? this.quantity,
        title: title ?? this.title,
        unitPriceMinor: unitPriceMinor ?? this.unitPriceMinor,
        currency: currency ?? this.currency,
        thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
        stockStatus: stockStatus ?? this.stockStatus,
        withdrawn: withdrawn ?? this.withdrawn,
        addedAt: addedAt ?? this.addedAt,
      );
  CartLine copyWithCompanion(CartLinesCompanion data) {
    return CartLine(
      productId: data.productId.present ? data.productId.value : this.productId,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      title: data.title.present ? data.title.value : this.title,
      unitPriceMinor: data.unitPriceMinor.present
          ? data.unitPriceMinor.value
          : this.unitPriceMinor,
      currency: data.currency.present ? data.currency.value : this.currency,
      thumbnailUrl: data.thumbnailUrl.present
          ? data.thumbnailUrl.value
          : this.thumbnailUrl,
      stockStatus:
          data.stockStatus.present ? data.stockStatus.value : this.stockStatus,
      withdrawn: data.withdrawn.present ? data.withdrawn.value : this.withdrawn,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CartLine(')
          ..write('productId: $productId, ')
          ..write('quantity: $quantity, ')
          ..write('title: $title, ')
          ..write('unitPriceMinor: $unitPriceMinor, ')
          ..write('currency: $currency, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('stockStatus: $stockStatus, ')
          ..write('withdrawn: $withdrawn, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(productId, quantity, title, unitPriceMinor,
      currency, thumbnailUrl, stockStatus, withdrawn, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CartLine &&
          other.productId == this.productId &&
          other.quantity == this.quantity &&
          other.title == this.title &&
          other.unitPriceMinor == this.unitPriceMinor &&
          other.currency == this.currency &&
          other.thumbnailUrl == this.thumbnailUrl &&
          other.stockStatus == this.stockStatus &&
          other.withdrawn == this.withdrawn &&
          other.addedAt == this.addedAt);
}

class CartLinesCompanion extends UpdateCompanion<CartLine> {
  final Value<String> productId;
  final Value<int> quantity;
  final Value<String> title;
  final Value<int> unitPriceMinor;
  final Value<String> currency;
  final Value<String> thumbnailUrl;
  final Value<String> stockStatus;
  final Value<bool> withdrawn;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const CartLinesCompanion({
    this.productId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.title = const Value.absent(),
    this.unitPriceMinor = const Value.absent(),
    this.currency = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.stockStatus = const Value.absent(),
    this.withdrawn = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CartLinesCompanion.insert({
    required String productId,
    required int quantity,
    required String title,
    required int unitPriceMinor,
    required String currency,
    required String thumbnailUrl,
    this.stockStatus = const Value.absent(),
    this.withdrawn = const Value.absent(),
    required DateTime addedAt,
    this.rowid = const Value.absent(),
  })  : productId = Value(productId),
        quantity = Value(quantity),
        title = Value(title),
        unitPriceMinor = Value(unitPriceMinor),
        currency = Value(currency),
        thumbnailUrl = Value(thumbnailUrl),
        addedAt = Value(addedAt);
  static Insertable<CartLine> custom({
    Expression<String>? productId,
    Expression<int>? quantity,
    Expression<String>? title,
    Expression<int>? unitPriceMinor,
    Expression<String>? currency,
    Expression<String>? thumbnailUrl,
    Expression<String>? stockStatus,
    Expression<bool>? withdrawn,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (productId != null) 'product_id': productId,
      if (quantity != null) 'quantity': quantity,
      if (title != null) 'title': title,
      if (unitPriceMinor != null) 'unit_price_minor': unitPriceMinor,
      if (currency != null) 'currency': currency,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (stockStatus != null) 'stock_status': stockStatus,
      if (withdrawn != null) 'withdrawn': withdrawn,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CartLinesCompanion copyWith(
      {Value<String>? productId,
      Value<int>? quantity,
      Value<String>? title,
      Value<int>? unitPriceMinor,
      Value<String>? currency,
      Value<String>? thumbnailUrl,
      Value<String>? stockStatus,
      Value<bool>? withdrawn,
      Value<DateTime>? addedAt,
      Value<int>? rowid}) {
    return CartLinesCompanion(
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      title: title ?? this.title,
      unitPriceMinor: unitPriceMinor ?? this.unitPriceMinor,
      currency: currency ?? this.currency,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      stockStatus: stockStatus ?? this.stockStatus,
      withdrawn: withdrawn ?? this.withdrawn,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (unitPriceMinor.present) {
      map['unit_price_minor'] = Variable<int>(unitPriceMinor.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (thumbnailUrl.present) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl.value);
    }
    if (stockStatus.present) {
      map['stock_status'] = Variable<String>(stockStatus.value);
    }
    if (withdrawn.present) {
      map['withdrawn'] = Variable<bool>(withdrawn.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CartLinesCompanion(')
          ..write('productId: $productId, ')
          ..write('quantity: $quantity, ')
          ..write('title: $title, ')
          ..write('unitPriceMinor: $unitPriceMinor, ')
          ..write('currency: $currency, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('stockStatus: $stockStatus, ')
          ..write('withdrawn: $withdrawn, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedOrdersTable extends CachedOrders
    with TableInfo<$CachedOrdersTable, CachedOrder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedOrdersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _orderNumberMeta =
      const VerificationMeta('orderNumber');
  @override
  late final GeneratedColumn<String> orderNumber = GeneratedColumn<String>(
      'order_number', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _totalMinorMeta =
      const VerificationMeta('totalMinor');
  @override
  late final GeneratedColumn<int> totalMinor = GeneratedColumn<int>(
      'total_minor', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _currentStageMeta =
      const VerificationMeta('currentStage');
  @override
  late final GeneratedColumn<String> currentStage = GeneratedColumn<String>(
      'current_stage', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _itemCountMeta =
      const VerificationMeta('itemCount');
  @override
  late final GeneratedColumn<int> itemCount = GeneratedColumn<int>(
      'item_count', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _thumbnailUrlMeta =
      const VerificationMeta('thumbnailUrl');
  @override
  late final GeneratedColumn<String> thumbnailUrl = GeneratedColumn<String>(
      'thumbnail_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _positionMeta =
      const VerificationMeta('position');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
      'position', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _fetchedAtMeta =
      const VerificationMeta('fetchedAt');
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
      'fetched_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        orderNumber,
        createdAt,
        totalMinor,
        currency,
        currentStage,
        itemCount,
        thumbnailUrl,
        position,
        fetchedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_orders';
  @override
  VerificationContext validateIntegrity(Insertable<CachedOrder> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('order_number')) {
      context.handle(
          _orderNumberMeta,
          orderNumber.isAcceptableOrUnknown(
              data['order_number']!, _orderNumberMeta));
    } else if (isInserting) {
      context.missing(_orderNumberMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('total_minor')) {
      context.handle(
          _totalMinorMeta,
          totalMinor.isAcceptableOrUnknown(
              data['total_minor']!, _totalMinorMeta));
    } else if (isInserting) {
      context.missing(_totalMinorMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('current_stage')) {
      context.handle(
          _currentStageMeta,
          currentStage.isAcceptableOrUnknown(
              data['current_stage']!, _currentStageMeta));
    } else if (isInserting) {
      context.missing(_currentStageMeta);
    }
    if (data.containsKey('item_count')) {
      context.handle(_itemCountMeta,
          itemCount.isAcceptableOrUnknown(data['item_count']!, _itemCountMeta));
    } else if (isInserting) {
      context.missing(_itemCountMeta);
    }
    if (data.containsKey('thumbnail_url')) {
      context.handle(
          _thumbnailUrlMeta,
          thumbnailUrl.isAcceptableOrUnknown(
              data['thumbnail_url']!, _thumbnailUrlMeta));
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta,
          position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(_fetchedAtMeta,
          fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta));
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedOrder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedOrder(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      orderNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}order_number'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      totalMinor: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_minor'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      currentStage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}current_stage'])!,
      itemCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}item_count'])!,
      thumbnailUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}thumbnail_url']),
      position: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position'])!,
      fetchedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}fetched_at'])!,
    );
  }

  @override
  $CachedOrdersTable createAlias(String alias) {
    return $CachedOrdersTable(attachedDatabase, alias);
  }
}

class CachedOrder extends DataClass implements Insertable<CachedOrder> {
  final String id;
  final String orderNumber;
  final DateTime createdAt;
  final int totalMinor;
  final String currency;
  final String currentStage;
  final int itemCount;
  final String? thumbnailUrl;

  /// Position in the server's ordering, so a cached page replays in the order it arrived.
  final int position;
  final DateTime fetchedAt;
  const CachedOrder(
      {required this.id,
      required this.orderNumber,
      required this.createdAt,
      required this.totalMinor,
      required this.currency,
      required this.currentStage,
      required this.itemCount,
      this.thumbnailUrl,
      required this.position,
      required this.fetchedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['order_number'] = Variable<String>(orderNumber);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['total_minor'] = Variable<int>(totalMinor);
    map['currency'] = Variable<String>(currency);
    map['current_stage'] = Variable<String>(currentStage);
    map['item_count'] = Variable<int>(itemCount);
    if (!nullToAbsent || thumbnailUrl != null) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl);
    }
    map['position'] = Variable<int>(position);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  CachedOrdersCompanion toCompanion(bool nullToAbsent) {
    return CachedOrdersCompanion(
      id: Value(id),
      orderNumber: Value(orderNumber),
      createdAt: Value(createdAt),
      totalMinor: Value(totalMinor),
      currency: Value(currency),
      currentStage: Value(currentStage),
      itemCount: Value(itemCount),
      thumbnailUrl: thumbnailUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailUrl),
      position: Value(position),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory CachedOrder.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedOrder(
      id: serializer.fromJson<String>(json['id']),
      orderNumber: serializer.fromJson<String>(json['orderNumber']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      totalMinor: serializer.fromJson<int>(json['totalMinor']),
      currency: serializer.fromJson<String>(json['currency']),
      currentStage: serializer.fromJson<String>(json['currentStage']),
      itemCount: serializer.fromJson<int>(json['itemCount']),
      thumbnailUrl: serializer.fromJson<String?>(json['thumbnailUrl']),
      position: serializer.fromJson<int>(json['position']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'orderNumber': serializer.toJson<String>(orderNumber),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'totalMinor': serializer.toJson<int>(totalMinor),
      'currency': serializer.toJson<String>(currency),
      'currentStage': serializer.toJson<String>(currentStage),
      'itemCount': serializer.toJson<int>(itemCount),
      'thumbnailUrl': serializer.toJson<String?>(thumbnailUrl),
      'position': serializer.toJson<int>(position),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  CachedOrder copyWith(
          {String? id,
          String? orderNumber,
          DateTime? createdAt,
          int? totalMinor,
          String? currency,
          String? currentStage,
          int? itemCount,
          Value<String?> thumbnailUrl = const Value.absent(),
          int? position,
          DateTime? fetchedAt}) =>
      CachedOrder(
        id: id ?? this.id,
        orderNumber: orderNumber ?? this.orderNumber,
        createdAt: createdAt ?? this.createdAt,
        totalMinor: totalMinor ?? this.totalMinor,
        currency: currency ?? this.currency,
        currentStage: currentStage ?? this.currentStage,
        itemCount: itemCount ?? this.itemCount,
        thumbnailUrl:
            thumbnailUrl.present ? thumbnailUrl.value : this.thumbnailUrl,
        position: position ?? this.position,
        fetchedAt: fetchedAt ?? this.fetchedAt,
      );
  CachedOrder copyWithCompanion(CachedOrdersCompanion data) {
    return CachedOrder(
      id: data.id.present ? data.id.value : this.id,
      orderNumber:
          data.orderNumber.present ? data.orderNumber.value : this.orderNumber,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      totalMinor:
          data.totalMinor.present ? data.totalMinor.value : this.totalMinor,
      currency: data.currency.present ? data.currency.value : this.currency,
      currentStage: data.currentStage.present
          ? data.currentStage.value
          : this.currentStage,
      itemCount: data.itemCount.present ? data.itemCount.value : this.itemCount,
      thumbnailUrl: data.thumbnailUrl.present
          ? data.thumbnailUrl.value
          : this.thumbnailUrl,
      position: data.position.present ? data.position.value : this.position,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedOrder(')
          ..write('id: $id, ')
          ..write('orderNumber: $orderNumber, ')
          ..write('createdAt: $createdAt, ')
          ..write('totalMinor: $totalMinor, ')
          ..write('currency: $currency, ')
          ..write('currentStage: $currentStage, ')
          ..write('itemCount: $itemCount, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('position: $position, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, orderNumber, createdAt, totalMinor,
      currency, currentStage, itemCount, thumbnailUrl, position, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedOrder &&
          other.id == this.id &&
          other.orderNumber == this.orderNumber &&
          other.createdAt == this.createdAt &&
          other.totalMinor == this.totalMinor &&
          other.currency == this.currency &&
          other.currentStage == this.currentStage &&
          other.itemCount == this.itemCount &&
          other.thumbnailUrl == this.thumbnailUrl &&
          other.position == this.position &&
          other.fetchedAt == this.fetchedAt);
}

class CachedOrdersCompanion extends UpdateCompanion<CachedOrder> {
  final Value<String> id;
  final Value<String> orderNumber;
  final Value<DateTime> createdAt;
  final Value<int> totalMinor;
  final Value<String> currency;
  final Value<String> currentStage;
  final Value<int> itemCount;
  final Value<String?> thumbnailUrl;
  final Value<int> position;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const CachedOrdersCompanion({
    this.id = const Value.absent(),
    this.orderNumber = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.totalMinor = const Value.absent(),
    this.currency = const Value.absent(),
    this.currentStage = const Value.absent(),
    this.itemCount = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.position = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedOrdersCompanion.insert({
    required String id,
    required String orderNumber,
    required DateTime createdAt,
    required int totalMinor,
    required String currency,
    required String currentStage,
    required int itemCount,
    this.thumbnailUrl = const Value.absent(),
    required int position,
    required DateTime fetchedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        orderNumber = Value(orderNumber),
        createdAt = Value(createdAt),
        totalMinor = Value(totalMinor),
        currency = Value(currency),
        currentStage = Value(currentStage),
        itemCount = Value(itemCount),
        position = Value(position),
        fetchedAt = Value(fetchedAt);
  static Insertable<CachedOrder> custom({
    Expression<String>? id,
    Expression<String>? orderNumber,
    Expression<DateTime>? createdAt,
    Expression<int>? totalMinor,
    Expression<String>? currency,
    Expression<String>? currentStage,
    Expression<int>? itemCount,
    Expression<String>? thumbnailUrl,
    Expression<int>? position,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (orderNumber != null) 'order_number': orderNumber,
      if (createdAt != null) 'created_at': createdAt,
      if (totalMinor != null) 'total_minor': totalMinor,
      if (currency != null) 'currency': currency,
      if (currentStage != null) 'current_stage': currentStage,
      if (itemCount != null) 'item_count': itemCount,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (position != null) 'position': position,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedOrdersCompanion copyWith(
      {Value<String>? id,
      Value<String>? orderNumber,
      Value<DateTime>? createdAt,
      Value<int>? totalMinor,
      Value<String>? currency,
      Value<String>? currentStage,
      Value<int>? itemCount,
      Value<String?>? thumbnailUrl,
      Value<int>? position,
      Value<DateTime>? fetchedAt,
      Value<int>? rowid}) {
    return CachedOrdersCompanion(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      createdAt: createdAt ?? this.createdAt,
      totalMinor: totalMinor ?? this.totalMinor,
      currency: currency ?? this.currency,
      currentStage: currentStage ?? this.currentStage,
      itemCount: itemCount ?? this.itemCount,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      position: position ?? this.position,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (orderNumber.present) {
      map['order_number'] = Variable<String>(orderNumber.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (totalMinor.present) {
      map['total_minor'] = Variable<int>(totalMinor.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (currentStage.present) {
      map['current_stage'] = Variable<String>(currentStage.value);
    }
    if (itemCount.present) {
      map['item_count'] = Variable<int>(itemCount.value);
    }
    if (thumbnailUrl.present) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedOrdersCompanion(')
          ..write('id: $id, ')
          ..write('orderNumber: $orderNumber, ')
          ..write('createdAt: $createdAt, ')
          ..write('totalMinor: $totalMinor, ')
          ..write('currency: $currency, ')
          ..write('currentStage: $currentStage, ')
          ..write('itemCount: $itemCount, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('position: $position, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$CacheDatabase extends GeneratedDatabase {
  _$CacheDatabase(QueryExecutor e) : super(e);
  $CacheDatabaseManager get managers => $CacheDatabaseManager(this);
  late final $CachedCategoriesTable cachedCategories =
      $CachedCategoriesTable(this);
  late final $CachedProductsTable cachedProducts = $CachedProductsTable(this);
  late final $CacheEntriesTable cacheEntries = $CacheEntriesTable(this);
  late final $CartLinesTable cartLines = $CartLinesTable(this);
  late final $CachedOrdersTable cachedOrders = $CachedOrdersTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [cachedCategories, cachedProducts, cacheEntries, cartLines, cachedOrders];
}

typedef $$CachedCategoriesTableCreateCompanionBuilder
    = CachedCategoriesCompanion Function({
  required String id,
  required String slug,
  required String name,
  Value<String?> imageUrl,
  Value<String?> parentId,
  required int sortOrder,
  required DateTime fetchedAt,
  Value<int> rowid,
});
typedef $$CachedCategoriesTableUpdateCompanionBuilder
    = CachedCategoriesCompanion Function({
  Value<String> id,
  Value<String> slug,
  Value<String> name,
  Value<String?> imageUrl,
  Value<String?> parentId,
  Value<int> sortOrder,
  Value<DateTime> fetchedAt,
  Value<int> rowid,
});

class $$CachedCategoriesTableFilterComposer
    extends Composer<_$CacheDatabase, $CachedCategoriesTable> {
  $$CachedCategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get slug => $composableBuilder(
      column: $table.slug, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get parentId => $composableBuilder(
      column: $table.parentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnFilters(column));
}

class $$CachedCategoriesTableOrderingComposer
    extends Composer<_$CacheDatabase, $CachedCategoriesTable> {
  $$CachedCategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get slug => $composableBuilder(
      column: $table.slug, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get parentId => $composableBuilder(
      column: $table.parentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnOrderings(column));
}

class $$CachedCategoriesTableAnnotationComposer
    extends Composer<_$CacheDatabase, $CachedCategoriesTable> {
  $$CachedCategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get slug =>
      $composableBuilder(column: $table.slug, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$CachedCategoriesTableTableManager extends RootTableManager<
    _$CacheDatabase,
    $CachedCategoriesTable,
    CachedCategory,
    $$CachedCategoriesTableFilterComposer,
    $$CachedCategoriesTableOrderingComposer,
    $$CachedCategoriesTableAnnotationComposer,
    $$CachedCategoriesTableCreateCompanionBuilder,
    $$CachedCategoriesTableUpdateCompanionBuilder,
    (
      CachedCategory,
      BaseReferences<_$CacheDatabase, $CachedCategoriesTable, CachedCategory>
    ),
    CachedCategory,
    PrefetchHooks Function()> {
  $$CachedCategoriesTableTableManager(
      _$CacheDatabase db, $CachedCategoriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedCategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedCategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedCategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> slug = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<String?> parentId = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<DateTime> fetchedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedCategoriesCompanion(
            id: id,
            slug: slug,
            name: name,
            imageUrl: imageUrl,
            parentId: parentId,
            sortOrder: sortOrder,
            fetchedAt: fetchedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String slug,
            required String name,
            Value<String?> imageUrl = const Value.absent(),
            Value<String?> parentId = const Value.absent(),
            required int sortOrder,
            required DateTime fetchedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedCategoriesCompanion.insert(
            id: id,
            slug: slug,
            name: name,
            imageUrl: imageUrl,
            parentId: parentId,
            sortOrder: sortOrder,
            fetchedAt: fetchedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CachedCategoriesTableProcessedTableManager = ProcessedTableManager<
    _$CacheDatabase,
    $CachedCategoriesTable,
    CachedCategory,
    $$CachedCategoriesTableFilterComposer,
    $$CachedCategoriesTableOrderingComposer,
    $$CachedCategoriesTableAnnotationComposer,
    $$CachedCategoriesTableCreateCompanionBuilder,
    $$CachedCategoriesTableUpdateCompanionBuilder,
    (
      CachedCategory,
      BaseReferences<_$CacheDatabase, $CachedCategoriesTable, CachedCategory>
    ),
    CachedCategory,
    PrefetchHooks Function()>;
typedef $$CachedProductsTableCreateCompanionBuilder = CachedProductsCompanion
    Function({
  required String id,
  required String title,
  required int priceMinor,
  required String currency,
  Value<int?> originalPriceMinor,
  required String thumbnailUrl,
  required String thumbnailAlt,
  required double ratingAverage,
  required int ratingCount,
  required String stockStatus,
  Value<String?> categorySlug,
  required int position,
  required DateTime fetchedAt,
  Value<int> rowid,
});
typedef $$CachedProductsTableUpdateCompanionBuilder = CachedProductsCompanion
    Function({
  Value<String> id,
  Value<String> title,
  Value<int> priceMinor,
  Value<String> currency,
  Value<int?> originalPriceMinor,
  Value<String> thumbnailUrl,
  Value<String> thumbnailAlt,
  Value<double> ratingAverage,
  Value<int> ratingCount,
  Value<String> stockStatus,
  Value<String?> categorySlug,
  Value<int> position,
  Value<DateTime> fetchedAt,
  Value<int> rowid,
});

class $$CachedProductsTableFilterComposer
    extends Composer<_$CacheDatabase, $CachedProductsTable> {
  $$CachedProductsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get priceMinor => $composableBuilder(
      column: $table.priceMinor, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get originalPriceMinor => $composableBuilder(
      column: $table.originalPriceMinor,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get thumbnailUrl => $composableBuilder(
      column: $table.thumbnailUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get thumbnailAlt => $composableBuilder(
      column: $table.thumbnailAlt, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get ratingAverage => $composableBuilder(
      column: $table.ratingAverage, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ratingCount => $composableBuilder(
      column: $table.ratingCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get stockStatus => $composableBuilder(
      column: $table.stockStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get categorySlug => $composableBuilder(
      column: $table.categorySlug, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnFilters(column));
}

class $$CachedProductsTableOrderingComposer
    extends Composer<_$CacheDatabase, $CachedProductsTable> {
  $$CachedProductsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get priceMinor => $composableBuilder(
      column: $table.priceMinor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get originalPriceMinor => $composableBuilder(
      column: $table.originalPriceMinor,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get thumbnailUrl => $composableBuilder(
      column: $table.thumbnailUrl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get thumbnailAlt => $composableBuilder(
      column: $table.thumbnailAlt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get ratingAverage => $composableBuilder(
      column: $table.ratingAverage,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ratingCount => $composableBuilder(
      column: $table.ratingCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get stockStatus => $composableBuilder(
      column: $table.stockStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get categorySlug => $composableBuilder(
      column: $table.categorySlug,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnOrderings(column));
}

class $$CachedProductsTableAnnotationComposer
    extends Composer<_$CacheDatabase, $CachedProductsTable> {
  $$CachedProductsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get priceMinor => $composableBuilder(
      column: $table.priceMinor, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<int> get originalPriceMinor => $composableBuilder(
      column: $table.originalPriceMinor, builder: (column) => column);

  GeneratedColumn<String> get thumbnailUrl => $composableBuilder(
      column: $table.thumbnailUrl, builder: (column) => column);

  GeneratedColumn<String> get thumbnailAlt => $composableBuilder(
      column: $table.thumbnailAlt, builder: (column) => column);

  GeneratedColumn<double> get ratingAverage => $composableBuilder(
      column: $table.ratingAverage, builder: (column) => column);

  GeneratedColumn<int> get ratingCount => $composableBuilder(
      column: $table.ratingCount, builder: (column) => column);

  GeneratedColumn<String> get stockStatus => $composableBuilder(
      column: $table.stockStatus, builder: (column) => column);

  GeneratedColumn<String> get categorySlug => $composableBuilder(
      column: $table.categorySlug, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$CachedProductsTableTableManager extends RootTableManager<
    _$CacheDatabase,
    $CachedProductsTable,
    CachedProduct,
    $$CachedProductsTableFilterComposer,
    $$CachedProductsTableOrderingComposer,
    $$CachedProductsTableAnnotationComposer,
    $$CachedProductsTableCreateCompanionBuilder,
    $$CachedProductsTableUpdateCompanionBuilder,
    (
      CachedProduct,
      BaseReferences<_$CacheDatabase, $CachedProductsTable, CachedProduct>
    ),
    CachedProduct,
    PrefetchHooks Function()> {
  $$CachedProductsTableTableManager(
      _$CacheDatabase db, $CachedProductsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedProductsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedProductsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedProductsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<int> priceMinor = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<int?> originalPriceMinor = const Value.absent(),
            Value<String> thumbnailUrl = const Value.absent(),
            Value<String> thumbnailAlt = const Value.absent(),
            Value<double> ratingAverage = const Value.absent(),
            Value<int> ratingCount = const Value.absent(),
            Value<String> stockStatus = const Value.absent(),
            Value<String?> categorySlug = const Value.absent(),
            Value<int> position = const Value.absent(),
            Value<DateTime> fetchedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedProductsCompanion(
            id: id,
            title: title,
            priceMinor: priceMinor,
            currency: currency,
            originalPriceMinor: originalPriceMinor,
            thumbnailUrl: thumbnailUrl,
            thumbnailAlt: thumbnailAlt,
            ratingAverage: ratingAverage,
            ratingCount: ratingCount,
            stockStatus: stockStatus,
            categorySlug: categorySlug,
            position: position,
            fetchedAt: fetchedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String title,
            required int priceMinor,
            required String currency,
            Value<int?> originalPriceMinor = const Value.absent(),
            required String thumbnailUrl,
            required String thumbnailAlt,
            required double ratingAverage,
            required int ratingCount,
            required String stockStatus,
            Value<String?> categorySlug = const Value.absent(),
            required int position,
            required DateTime fetchedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedProductsCompanion.insert(
            id: id,
            title: title,
            priceMinor: priceMinor,
            currency: currency,
            originalPriceMinor: originalPriceMinor,
            thumbnailUrl: thumbnailUrl,
            thumbnailAlt: thumbnailAlt,
            ratingAverage: ratingAverage,
            ratingCount: ratingCount,
            stockStatus: stockStatus,
            categorySlug: categorySlug,
            position: position,
            fetchedAt: fetchedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CachedProductsTableProcessedTableManager = ProcessedTableManager<
    _$CacheDatabase,
    $CachedProductsTable,
    CachedProduct,
    $$CachedProductsTableFilterComposer,
    $$CachedProductsTableOrderingComposer,
    $$CachedProductsTableAnnotationComposer,
    $$CachedProductsTableCreateCompanionBuilder,
    $$CachedProductsTableUpdateCompanionBuilder,
    (
      CachedProduct,
      BaseReferences<_$CacheDatabase, $CachedProductsTable, CachedProduct>
    ),
    CachedProduct,
    PrefetchHooks Function()>;
typedef $$CacheEntriesTableCreateCompanionBuilder = CacheEntriesCompanion
    Function({
  required String key,
  required DateTime fetchedAt,
  Value<int> rowid,
});
typedef $$CacheEntriesTableUpdateCompanionBuilder = CacheEntriesCompanion
    Function({
  Value<String> key,
  Value<DateTime> fetchedAt,
  Value<int> rowid,
});

class $$CacheEntriesTableFilterComposer
    extends Composer<_$CacheDatabase, $CacheEntriesTable> {
  $$CacheEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnFilters(column));
}

class $$CacheEntriesTableOrderingComposer
    extends Composer<_$CacheDatabase, $CacheEntriesTable> {
  $$CacheEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnOrderings(column));
}

class $$CacheEntriesTableAnnotationComposer
    extends Composer<_$CacheDatabase, $CacheEntriesTable> {
  $$CacheEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$CacheEntriesTableTableManager extends RootTableManager<
    _$CacheDatabase,
    $CacheEntriesTable,
    CacheEntry,
    $$CacheEntriesTableFilterComposer,
    $$CacheEntriesTableOrderingComposer,
    $$CacheEntriesTableAnnotationComposer,
    $$CacheEntriesTableCreateCompanionBuilder,
    $$CacheEntriesTableUpdateCompanionBuilder,
    (
      CacheEntry,
      BaseReferences<_$CacheDatabase, $CacheEntriesTable, CacheEntry>
    ),
    CacheEntry,
    PrefetchHooks Function()> {
  $$CacheEntriesTableTableManager(_$CacheDatabase db, $CacheEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CacheEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CacheEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CacheEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<DateTime> fetchedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CacheEntriesCompanion(
            key: key,
            fetchedAt: fetchedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required DateTime fetchedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              CacheEntriesCompanion.insert(
            key: key,
            fetchedAt: fetchedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CacheEntriesTableProcessedTableManager = ProcessedTableManager<
    _$CacheDatabase,
    $CacheEntriesTable,
    CacheEntry,
    $$CacheEntriesTableFilterComposer,
    $$CacheEntriesTableOrderingComposer,
    $$CacheEntriesTableAnnotationComposer,
    $$CacheEntriesTableCreateCompanionBuilder,
    $$CacheEntriesTableUpdateCompanionBuilder,
    (
      CacheEntry,
      BaseReferences<_$CacheDatabase, $CacheEntriesTable, CacheEntry>
    ),
    CacheEntry,
    PrefetchHooks Function()>;
typedef $$CartLinesTableCreateCompanionBuilder = CartLinesCompanion Function({
  required String productId,
  required int quantity,
  required String title,
  required int unitPriceMinor,
  required String currency,
  required String thumbnailUrl,
  Value<String> stockStatus,
  Value<bool> withdrawn,
  required DateTime addedAt,
  Value<int> rowid,
});
typedef $$CartLinesTableUpdateCompanionBuilder = CartLinesCompanion Function({
  Value<String> productId,
  Value<int> quantity,
  Value<String> title,
  Value<int> unitPriceMinor,
  Value<String> currency,
  Value<String> thumbnailUrl,
  Value<String> stockStatus,
  Value<bool> withdrawn,
  Value<DateTime> addedAt,
  Value<int> rowid,
});

class $$CartLinesTableFilterComposer
    extends Composer<_$CacheDatabase, $CartLinesTable> {
  $$CartLinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get productId => $composableBuilder(
      column: $table.productId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get unitPriceMinor => $composableBuilder(
      column: $table.unitPriceMinor,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get thumbnailUrl => $composableBuilder(
      column: $table.thumbnailUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get stockStatus => $composableBuilder(
      column: $table.stockStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get withdrawn => $composableBuilder(
      column: $table.withdrawn, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
      column: $table.addedAt, builder: (column) => ColumnFilters(column));
}

class $$CartLinesTableOrderingComposer
    extends Composer<_$CacheDatabase, $CartLinesTable> {
  $$CartLinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get productId => $composableBuilder(
      column: $table.productId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get unitPriceMinor => $composableBuilder(
      column: $table.unitPriceMinor,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get thumbnailUrl => $composableBuilder(
      column: $table.thumbnailUrl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get stockStatus => $composableBuilder(
      column: $table.stockStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get withdrawn => $composableBuilder(
      column: $table.withdrawn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
      column: $table.addedAt, builder: (column) => ColumnOrderings(column));
}

class $$CartLinesTableAnnotationComposer
    extends Composer<_$CacheDatabase, $CartLinesTable> {
  $$CartLinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get unitPriceMinor => $composableBuilder(
      column: $table.unitPriceMinor, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get thumbnailUrl => $composableBuilder(
      column: $table.thumbnailUrl, builder: (column) => column);

  GeneratedColumn<String> get stockStatus => $composableBuilder(
      column: $table.stockStatus, builder: (column) => column);

  GeneratedColumn<bool> get withdrawn =>
      $composableBuilder(column: $table.withdrawn, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$CartLinesTableTableManager extends RootTableManager<
    _$CacheDatabase,
    $CartLinesTable,
    CartLine,
    $$CartLinesTableFilterComposer,
    $$CartLinesTableOrderingComposer,
    $$CartLinesTableAnnotationComposer,
    $$CartLinesTableCreateCompanionBuilder,
    $$CartLinesTableUpdateCompanionBuilder,
    (CartLine, BaseReferences<_$CacheDatabase, $CartLinesTable, CartLine>),
    CartLine,
    PrefetchHooks Function()> {
  $$CartLinesTableTableManager(_$CacheDatabase db, $CartLinesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CartLinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CartLinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CartLinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> productId = const Value.absent(),
            Value<int> quantity = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<int> unitPriceMinor = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<String> thumbnailUrl = const Value.absent(),
            Value<String> stockStatus = const Value.absent(),
            Value<bool> withdrawn = const Value.absent(),
            Value<DateTime> addedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CartLinesCompanion(
            productId: productId,
            quantity: quantity,
            title: title,
            unitPriceMinor: unitPriceMinor,
            currency: currency,
            thumbnailUrl: thumbnailUrl,
            stockStatus: stockStatus,
            withdrawn: withdrawn,
            addedAt: addedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String productId,
            required int quantity,
            required String title,
            required int unitPriceMinor,
            required String currency,
            required String thumbnailUrl,
            Value<String> stockStatus = const Value.absent(),
            Value<bool> withdrawn = const Value.absent(),
            required DateTime addedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              CartLinesCompanion.insert(
            productId: productId,
            quantity: quantity,
            title: title,
            unitPriceMinor: unitPriceMinor,
            currency: currency,
            thumbnailUrl: thumbnailUrl,
            stockStatus: stockStatus,
            withdrawn: withdrawn,
            addedAt: addedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CartLinesTableProcessedTableManager = ProcessedTableManager<
    _$CacheDatabase,
    $CartLinesTable,
    CartLine,
    $$CartLinesTableFilterComposer,
    $$CartLinesTableOrderingComposer,
    $$CartLinesTableAnnotationComposer,
    $$CartLinesTableCreateCompanionBuilder,
    $$CartLinesTableUpdateCompanionBuilder,
    (CartLine, BaseReferences<_$CacheDatabase, $CartLinesTable, CartLine>),
    CartLine,
    PrefetchHooks Function()>;
typedef $$CachedOrdersTableCreateCompanionBuilder = CachedOrdersCompanion
    Function({
  required String id,
  required String orderNumber,
  required DateTime createdAt,
  required int totalMinor,
  required String currency,
  required String currentStage,
  required int itemCount,
  Value<String?> thumbnailUrl,
  required int position,
  required DateTime fetchedAt,
  Value<int> rowid,
});
typedef $$CachedOrdersTableUpdateCompanionBuilder = CachedOrdersCompanion
    Function({
  Value<String> id,
  Value<String> orderNumber,
  Value<DateTime> createdAt,
  Value<int> totalMinor,
  Value<String> currency,
  Value<String> currentStage,
  Value<int> itemCount,
  Value<String?> thumbnailUrl,
  Value<int> position,
  Value<DateTime> fetchedAt,
  Value<int> rowid,
});

class $$CachedOrdersTableFilterComposer
    extends Composer<_$CacheDatabase, $CachedOrdersTable> {
  $$CachedOrdersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get orderNumber => $composableBuilder(
      column: $table.orderNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalMinor => $composableBuilder(
      column: $table.totalMinor, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currentStage => $composableBuilder(
      column: $table.currentStage, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get itemCount => $composableBuilder(
      column: $table.itemCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get thumbnailUrl => $composableBuilder(
      column: $table.thumbnailUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnFilters(column));
}

class $$CachedOrdersTableOrderingComposer
    extends Composer<_$CacheDatabase, $CachedOrdersTable> {
  $$CachedOrdersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get orderNumber => $composableBuilder(
      column: $table.orderNumber, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalMinor => $composableBuilder(
      column: $table.totalMinor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currentStage => $composableBuilder(
      column: $table.currentStage,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get itemCount => $composableBuilder(
      column: $table.itemCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get thumbnailUrl => $composableBuilder(
      column: $table.thumbnailUrl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnOrderings(column));
}

class $$CachedOrdersTableAnnotationComposer
    extends Composer<_$CacheDatabase, $CachedOrdersTable> {
  $$CachedOrdersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get orderNumber => $composableBuilder(
      column: $table.orderNumber, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get totalMinor => $composableBuilder(
      column: $table.totalMinor, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get currentStage => $composableBuilder(
      column: $table.currentStage, builder: (column) => column);

  GeneratedColumn<int> get itemCount =>
      $composableBuilder(column: $table.itemCount, builder: (column) => column);

  GeneratedColumn<String> get thumbnailUrl => $composableBuilder(
      column: $table.thumbnailUrl, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$CachedOrdersTableTableManager extends RootTableManager<
    _$CacheDatabase,
    $CachedOrdersTable,
    CachedOrder,
    $$CachedOrdersTableFilterComposer,
    $$CachedOrdersTableOrderingComposer,
    $$CachedOrdersTableAnnotationComposer,
    $$CachedOrdersTableCreateCompanionBuilder,
    $$CachedOrdersTableUpdateCompanionBuilder,
    (
      CachedOrder,
      BaseReferences<_$CacheDatabase, $CachedOrdersTable, CachedOrder>
    ),
    CachedOrder,
    PrefetchHooks Function()> {
  $$CachedOrdersTableTableManager(_$CacheDatabase db, $CachedOrdersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedOrdersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedOrdersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedOrdersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> orderNumber = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> totalMinor = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<String> currentStage = const Value.absent(),
            Value<int> itemCount = const Value.absent(),
            Value<String?> thumbnailUrl = const Value.absent(),
            Value<int> position = const Value.absent(),
            Value<DateTime> fetchedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedOrdersCompanion(
            id: id,
            orderNumber: orderNumber,
            createdAt: createdAt,
            totalMinor: totalMinor,
            currency: currency,
            currentStage: currentStage,
            itemCount: itemCount,
            thumbnailUrl: thumbnailUrl,
            position: position,
            fetchedAt: fetchedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String orderNumber,
            required DateTime createdAt,
            required int totalMinor,
            required String currency,
            required String currentStage,
            required int itemCount,
            Value<String?> thumbnailUrl = const Value.absent(),
            required int position,
            required DateTime fetchedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedOrdersCompanion.insert(
            id: id,
            orderNumber: orderNumber,
            createdAt: createdAt,
            totalMinor: totalMinor,
            currency: currency,
            currentStage: currentStage,
            itemCount: itemCount,
            thumbnailUrl: thumbnailUrl,
            position: position,
            fetchedAt: fetchedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CachedOrdersTableProcessedTableManager = ProcessedTableManager<
    _$CacheDatabase,
    $CachedOrdersTable,
    CachedOrder,
    $$CachedOrdersTableFilterComposer,
    $$CachedOrdersTableOrderingComposer,
    $$CachedOrdersTableAnnotationComposer,
    $$CachedOrdersTableCreateCompanionBuilder,
    $$CachedOrdersTableUpdateCompanionBuilder,
    (
      CachedOrder,
      BaseReferences<_$CacheDatabase, $CachedOrdersTable, CachedOrder>
    ),
    CachedOrder,
    PrefetchHooks Function()>;

class $CacheDatabaseManager {
  final _$CacheDatabase _db;
  $CacheDatabaseManager(this._db);
  $$CachedCategoriesTableTableManager get cachedCategories =>
      $$CachedCategoriesTableTableManager(_db, _db.cachedCategories);
  $$CachedProductsTableTableManager get cachedProducts =>
      $$CachedProductsTableTableManager(_db, _db.cachedProducts);
  $$CacheEntriesTableTableManager get cacheEntries =>
      $$CacheEntriesTableTableManager(_db, _db.cacheEntries);
  $$CartLinesTableTableManager get cartLines =>
      $$CartLinesTableTableManager(_db, _db.cartLines);
  $$CachedOrdersTableTableManager get cachedOrders =>
      $$CachedOrdersTableTableManager(_db, _db.cachedOrders);
}
