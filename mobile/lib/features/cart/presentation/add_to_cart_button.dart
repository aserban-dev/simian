/// Add to cart (FR-018, FR-078).
///
/// Out of stock disables the action *and says so in words*. Greying the button out alone would
/// leave colour as the sole carrier of the meaning, which Principle VII forbids — and would
/// leave the user guessing whether the app was broken.
library;

import 'package:flutter/material.dart';

import '../../catalogue/domain/catalogue_models.dart';

class AddToCartButton extends StatelessWidget {
  const AddToCartButton({
    required this.stockStatus,
    required this.onAdd,
    super.key,
  });

  final StockStatus stockStatus;
  final VoidCallback onAdd;

  static const String addLabel = 'Add to cart';
  static const String outOfStockLabel = 'Out of stock';

  @override
  Widget build(BuildContext context) {
    // Low stock is still buyable — only out of stock is not (FR-078).
    final bool purchasable = stockStatus.isPurchasable;

    return FilledButton(
      onPressed: purchasable ? onAdd : null,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      child: Text(purchasable ? addLabel : outOfStockLabel),
    );
  }
}
