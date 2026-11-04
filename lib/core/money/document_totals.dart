import 'money.dart';

/// One editable line of a quotation or an order.
class LineInput {
  const LineInput({
    this.productId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.estimatedUnitCost = Money.zero,
    this.position = 0,
  });

  final String? productId;
  final String description;
  final double quantity;
  final Money unitPrice;
  final Money estimatedUnitCost;
  final int position;

  Money get lineTotal => unitPrice.multiply(quantity);

  Money get lineCost => estimatedUnitCost.multiply(quantity);

  /// Payload sent to the `rpc_save_quotation` / `rpc_save_order` functions.
  Map<String, dynamic> toRpcPayload() => {
        'product_id': productId ?? '',
        'description': description,
        'quantity': quantity,
        'unit_price_cents': unitPrice.cents,
        'estimated_cost_cents': estimatedUnitCost.cents,
        'position': position,
      };

  LineInput copyWith({
    String? productId,
    String? description,
    double? quantity,
    Money? unitPrice,
    Money? estimatedUnitCost,
    int? position,
  }) {
    return LineInput(
      productId: productId ?? this.productId,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      estimatedUnitCost: estimatedUnitCost ?? this.estimatedUnitCost,
      position: position ?? this.position,
    );
  }
}

/// The totals of a document, calculated exactly like the database does.
///
/// The server is always the source of truth (it recomputes every total), but
/// the client needs the same numbers to show a live preview while the user
/// types. Keeping the rounding rules identical avoids surprises when the
/// saved document differs from the preview.
class DocumentTotals {
  const DocumentTotals({
    required this.subtotal,
    required this.discountAmount,
    required this.netSales,
    required this.total,
    required this.estimatedCost,
  });

  final Money subtotal;
  final Money discountAmount;
  final Money netSales;
  final Money total;
  final Money estimatedCost;

  /// Computes the totals of a quotation or an order.
  ///
  /// * `discountType` is `none`, `percent` or `amount`.
  /// * `discountValue` is a percentage when the type is `percent`, otherwise
  ///   an amount in centavos.
  factory DocumentTotals.calculate({
    required List<LineInput> lines,
    required String discountType,
    required num discountValue,
  }) {
    var subtotal = Money.zero;
    var estimatedCost = Money.zero;

    for (final line in lines) {
      subtotal += line.lineTotal;
      estimatedCost += line.lineCost;
    }

    var discountAmount = Money.zero;
    switch (discountType) {
      case 'percent':
        discountAmount = Money.percentOf(subtotal, discountValue);
        break;
      case 'amount':
        discountAmount = Money(discountValue.round());
        if (discountAmount > subtotal) discountAmount = subtotal;
        break;
      default:
        discountAmount = Money.zero;
    }

    final netSales = subtotal - discountAmount;

    return DocumentTotals(
      subtotal: subtotal,
      discountAmount: discountAmount,
      netSales: netSales,
      total: netSales,
      estimatedCost: estimatedCost,
    );
  }
}
