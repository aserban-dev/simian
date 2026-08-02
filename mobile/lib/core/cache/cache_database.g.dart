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

abstract class _$CacheDatabase extends GeneratedDatabase {
  _$CacheDatabase(QueryExecutor e) : super(e);
  $CacheDatabaseManager get managers => $CacheDatabaseManager(this);
  late final $CachedCategoriesTable cachedCategories =
      $CachedCategoriesTable(this);
  late final $CachedProductsTable cachedProducts = $CachedProductsTable(this);
  late final $CacheEntriesTable cacheEntries = $CacheEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [cachedCategories, cachedProducts, cacheEntries];
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

class $CacheDatabaseManager {
  final _$CacheDatabase _db;
  $CacheDatabaseManager(this._db);
  $$CachedCategoriesTableTableManager get cachedCategories =>
      $$CachedCategoriesTableTableManager(_db, _db.cachedCategories);
  $$CachedProductsTableTableManager get cachedProducts =>
      $$CachedProductsTableTableManager(_db, _db.cachedProducts);
  $$CacheEntriesTableTableManager get cacheEntries =>
      $$CacheEntriesTableTableManager(_db, _db.cacheEntries);
}
