/// Order history types (T107).
///
/// Decoded by hand, like the catalogue models, so a malformed or partial payload degrades to
/// something renderable rather than throwing into the widget tree (Principle IV).
library;

import 'package:meta/meta.dart';

import '../../../core/currency/money.dart';
import 'parcel_position.dart';

@immutable
class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.orderNumber,
    required this.createdAt,
    required this.total,
    required this.currentStage,
    required this.itemCount,
    this.thumbnailUrl,
  });

  final String id;
  final String orderNumber;
  final DateTime createdAt;
  final Money total;

  /// As the server derived it at read time (FR-035). Recomputed on the device from the detail
  /// payload's timestamps when the map is open, so the two cannot disagree.
  final DeliveryStage currentStage;

  final int itemCount;
  final String? thumbnailUrl;

  factory OrderSummary.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> total = (json['total'] as Map<String, dynamic>?) ?? const {};
    return OrderSummary(
      id: json['id'] as String? ?? '',
      orderNumber: json['order_number'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toUtc() ??
          DateTime.utc(1970),
      total: Money(
        amountMinor: total['amount_minor'] as int? ?? 0,
        currency: total['currency'] as String? ?? 'EUR',
      ),
      currentStage: DeliveryStage.parse(json['current_stage']),
      itemCount: json['item_count'] as int? ?? 0,
      thumbnailUrl: json['thumbnail_url'] as String?,
    );
  }
}

@immutable
class OrderLine {
  const OrderLine({
    required this.productId,
    required this.title,
    required this.quantity,
    required this.unitPrice,
    required this.imageUrl,
  });

  final String productId;
  final String title;
  final int quantity;
  final Money unitPrice;
  final String imageUrl;

  Money get lineTotal => unitPrice * quantity;

  factory OrderLine.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> price = (json['unit_price'] as Map<String, dynamic>?) ?? const {};
    return OrderLine(
      productId: json['product_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 0,
      unitPrice: Money(
        amountMinor: price['amount_minor'] as int? ?? 0,
        currency: price['currency'] as String? ?? 'EUR',
      ),
      imageUrl: json['image_url'] as String? ?? '',
    );
  }
}

@immutable
class OrderDetail {
  const OrderDetail({
    required this.summary,
    required this.lines,
    required this.tracking,
    required this.addressFormatted,
    this.recipientName,
  });

  final OrderSummary summary;
  final List<OrderLine> lines;
  final DeliveryTracking tracking;

  /// The address as it was at purchase time (FR-044).
  final String addressFormatted;
  final String? recipientName;

  factory OrderDetail.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> address = (json['address'] as Map<String, dynamic>?) ?? const {};
    return OrderDetail(
      summary: OrderSummary.fromJson(json),
      lines: <OrderLine>[
        for (final Object? item in (json['items'] as List<Object?>?) ?? const <Object?>[])
          if (item is Map<String, dynamic>) OrderLine.fromJson(item),
      ],
      tracking: DeliveryTracking.fromJson(
        (json['tracking'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      addressFormatted: address['formatted'] as String? ?? '',
      recipientName: address['recipient_name'] as String?,
    );
  }
}
