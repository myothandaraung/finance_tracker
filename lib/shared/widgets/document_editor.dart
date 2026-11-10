import 'package:flutter/material.dart';

import '../../core/money/document_totals.dart';
import '../../core/money/money.dart';
import '../../core/money/money_format.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/app_text_field.dart';

/// Editable list of lines shared by the quotation and the order form.
class LineEditor extends StatelessWidget {
  const LineEditor({
    super.key,
    required this.lines,
    required this.onChanged,
    this.products = const [],
    this.allowEstimatedCost = true,
  });

  final List<LineInput> lines;
  final ValueChanged<List<LineInput>> onChanged;

  /// Products offered in the "add from catalog" menu.
  final List<({String id, String name, Money price, Money productionCost})>
  products;

  /// Orders and quotations both keep an estimated production cost per line.
  final bool allowEstimatedCost;

  void _update(int index, LineInput line) {
    final updated = [...lines];
    updated[index] = line;
    onChanged(updated);
  }

  void _remove(int index) {
    final updated = [...lines]..removeAt(index);
    onChanged(updated);
  }

  void _add() {
    onChanged([
      ...lines,
      const LineInput(description: '', quantity: 1, unitPrice: Money.zero),
    ]);
  }

  void _addFromProduct(
    String id,
    String name,
    Money price,
    Money productionCost,
  ) {
    final productLine = LineInput(
      productId: id,
      description: name,
      quantity: 1,
      unitPrice: price,
      estimatedUnitCost: productionCost,
    );

    // A new document starts with one empty line. Selecting a catalog item
    // should fill that line instead of leaving an unnecessary blank item.
    if (lines.length == 1 && _isBlank(lines.single)) {
      onChanged([productLine]);
      return;
    }

    onChanged([...lines, productLine]);
  }

  bool _isBlank(LineInput line) =>
      line.productId == null &&
      line.description.trim().isEmpty &&
      line.unitPrice == Money.zero &&
      line.estimatedUnitCost == Money.zero;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < lines.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _LineRow(
              key: ValueKey(index),
              line: lines[index],
              allowEstimatedCost: allowEstimatedCost,
              onChanged: (line) => _update(index, line),
              onRemove: lines.length > 1 ? () => _remove(index) : null,
            ),
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add line'),
              ),
            ),
            if (products.isNotEmpty) ...[
              const SizedBox(width: 8),
              Expanded(
                child: PopupMenuButton<String>(
                  onSelected: (id) {
                    final product = products.firstWhere(
                      (item) => item.id == id,
                    );
                    _addFromProduct(
                      product.id,
                      product.name,
                      product.price,
                      product.productionCost,
                    );
                  },
                  itemBuilder: (context) => [
                    for (final product in products)
                      PopupMenuItem<String>(
                        value: product.id,
                        child: Text(product.name),
                      ),
                  ],
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('From catalog'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _LineRow extends StatefulWidget {
  const _LineRow({
    super.key,
    required this.line,
    required this.onChanged,
    required this.onRemove,
    this.allowEstimatedCost = true,
  });

  final LineInput line;
  final ValueChanged<LineInput> onChanged;
  final VoidCallback? onRemove;
  final bool allowEstimatedCost;

  @override
  State<_LineRow> createState() => _LineRowState();
}

class _LineRowState extends State<_LineRow> {
  late final TextEditingController _descriptionController;
  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;
  late final TextEditingController _costController;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text: widget.line.description,
    );
    _quantityController = TextEditingController(
      text: _formatQuantity(widget.line.quantity),
    );
    _priceController = TextEditingController(text: widget.line.unitPrice.plain);
    _costController = TextEditingController(
      text: widget.line.estimatedUnitCost.plain,
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _costController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _LineRow oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Rows can be replaced after an order loads or a catalog item is chosen.
    // Keep the controllers aligned with the model so fields and totals cannot
    // display values from different lines.
    if (oldWidget.line.description != widget.line.description &&
        _descriptionController.text != widget.line.description) {
      _descriptionController.text = widget.line.description;
    }
    if (oldWidget.line.quantity != widget.line.quantity &&
        double.tryParse(_quantityController.text) != widget.line.quantity) {
      _quantityController.text = _formatQuantity(widget.line.quantity);
    }
    if (oldWidget.line.unitPrice != widget.line.unitPrice &&
        Money.tryParse(_priceController.text) != widget.line.unitPrice) {
      _priceController.text = widget.line.unitPrice.plain;
    }
    if (oldWidget.line.estimatedUnitCost != widget.line.estimatedUnitCost &&
        Money.tryParse(_costController.text) != widget.line.estimatedUnitCost) {
      _costController.text = widget.line.estimatedUnitCost.plain;
    }
  }

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toString();
  }

  void _emit({
    String? description,
    double? quantity,
    Money? unitPrice,
    Money? estimatedUnitCost,
  }) {
    widget.onChanged(
      widget.line.copyWith(
        description: description ?? _descriptionController.text,
        quantity: quantity ?? widget.line.quantity,
        unitPrice: unitPrice ?? widget.line.unitPrice,
        estimatedUnitCost: estimatedUnitCost ?? widget.line.estimatedUnitCost,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Description',
                    controller: _descriptionController,
                    onChanged: (value) => _emit(description: value),
                  ),
                ),
                if (widget.onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: AppColors.danger,
                    onPressed: widget.onRemove,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Qty',
                    controller: _quantityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (value) {
                      final parsed = double.tryParse(value);
                      if (parsed != null && parsed > 0) {
                        _emit(quantity: parsed);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: AmountField(
                    label: 'Unit price',
                    controller: _priceController,
                    onChanged: (value) => _emit(unitPrice: value),
                  ),
                ),
              ],
            ),
            if (widget.allowEstimatedCost) ...[
              const SizedBox(height: 10),
              AmountField(
                label: 'Estimated cost / unit',
                controller: _costController,
                onChanged: (value) => _emit(estimatedUnitCost: value),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Line total ${MoneyFormatter.format(widget.line.lineTotal)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Summary of the totals of a document, recalculated while the user types.
class TotalsPanel extends StatelessWidget {
  const TotalsPanel({
    super.key,
    required this.totals,
    required this.discountType,
    required this.discountValue,
  });

  final DocumentTotals totals;
  final String discountType;
  final num discountValue;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _TotalRow(
              label: 'Subtotal',
              value: MoneyFormatter.format(totals.subtotal),
            ),
            _TotalRow(
              label: discountType == 'percent'
                  ? 'Discount (${_trim(discountValue)}%)'
                  : 'Discount',
              value: '- ${MoneyFormatter.format(totals.discountAmount)}',
            ),
            const Divider(height: 18),
            _TotalRow(
              label: 'Total',
              value: MoneyFormatter.format(totals.total),
              bold: true,
            ),
            if (totals.estimatedCost.cents > 0)
              _TotalRow(
                label: 'Estimated production cost',
                value: MoneyFormatter.format(totals.estimatedCost),
                muted: true,
              ),
            _TotalRow(
              label: 'Estimated profit',
              value: MoneyFormatter.format(totals.estimatedProfit),
              bold: true,
            ),
          ],
        ),
      ),
    );
  }

  String _trim(num value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toString();
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.muted = false,
  });

  final String label;
  final String value;
  final bool bold;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                color: muted ? AppColors.textSecondary : AppColors.textPrimary,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 16 : 13.5,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color: muted ? AppColors.textSecondary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
