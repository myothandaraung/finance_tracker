import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/order_status.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/export/document_pdf.dart';
import '../../../core/export/export_service.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/info_row.dart';
import '../../../shared/widgets/section_title.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../business/providers/business_providers.dart';
import '../../payments/presentation/payment_sheet.dart';
import '../../payments/providers/payment_providers.dart';
import '../domain/order.dart';
import '../providers/order_providers.dart';
import 'order_cost_sheet.dart';

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(orderDetailProvider(orderId));
    final role = ref.watch(currentRoleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order'),
        actions: [
          detail.maybeWhen(
            data: (data) => Row(
              children: [
                if (role.canManageOperations && data.order.allowsItemEditing)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () =>
                        context.push('/app/orders/${data.order.id}/edit'),
                  ),
                PopupMenuButton<String>(
                  onSelected: (value) => _onMenu(context, ref, value, data),
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'print',
                      child: Text('Print / save as PDF'),
                    ),
                    PopupMenuItem(value: 'share', child: Text('Share PDF')),
                  ],
                ),
              ],
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(orderDetailProvider(orderId)),
        ),
        data: (data) {
          final order = data.order;
          final financials = data.financials;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(orderDetailProvider(orderId));
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              order.orderNo,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          StatusChip.order(order.status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      InfoRow(
                        label: 'Customer',
                        value: order.customerName,
                        icon: Icons.person_outline,
                      ),
                      InfoRow(
                        label: 'Created',
                        value: AppDate.format(order.createdAt),
                        icon: Icons.event_outlined,
                      ),
                      InfoRow(
                        label: 'Due date',
                        value: order.dueDate == null
                            ? '—'
                            : AppDate.format(order.dueDate),
                        icon: Icons.timer_outlined,
                      ),
                      InfoRow(
                        label: 'Delivered',
                        value: order.deliveredAt == null
                            ? '—'
                            : AppDate.format(order.deliveredAt),
                        icon: Icons.local_shipping_outlined,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                AppCard(
                  child: Column(
                    children: [
                      InfoRow(
                        label: 'Subtotal',
                        value: MoneyFormatter.format(order.subtotal),
                      ),
                      InfoRow(
                        label: 'Discount',
                        value:
                            '- ${MoneyFormatter.format(order.discountAmount)}',
                      ),
                      const Divider(height: 18),
                      InfoRow(
                        label: 'Total',
                        value: MoneyFormatter.format(order.totalAmount),
                        bold: true,
                      ),
                      InfoRow(
                        label: 'Paid',
                        value: MoneyFormatter.format(financials.paidAmount),
                        valueColor: AppColors.success,
                      ),
                      InfoRow(
                        label: 'Refunded',
                        value: MoneyFormatter.format(financials.refundedAmount),
                        valueColor: financials.refundedAmount.cents > 0
                            ? AppColors.warning
                            : null,
                      ),
                      InfoRow(
                        label: 'Outstanding',
                        value: MoneyFormatter.format(
                          financials.outstandingAmount,
                        ),
                        bold: true,
                        valueColor: financials.outstandingAmount.cents > 0
                            ? AppColors.danger
                            : AppColors.success,
                      ),
                      const Divider(height: 18),
                      InfoRow(
                        label: 'Estimated cost',
                        value: MoneyFormatter.format(financials.estimatedCost),
                      ),
                      if (financials.productionCostSource != null)
                        InfoRow(
                          label: 'Production cost source',
                          value: financials.productionCostSource == 'actual'
                              ? 'Actual (cost entries)'
                              : financials.productionCostSource ==
                                    'order_snapshot'
                              ? 'Saved with order'
                              : 'None',
                        ),
                      if (financials.estimatedProductionCost.cents > 0 &&
                          financials.productionCostSource != 'actual')
                        InfoRow(
                          label: 'Estimated production cost',
                          value: MoneyFormatter.format(
                            financials.estimatedProductionCost,
                          ),
                        ),
                      InfoRow(
                        label: 'Actual cost',
                        value: MoneyFormatter.format(financials.actualCost),
                      ),
                      InfoRow(
                        label: 'Profit',
                        value: MoneyFormatter.format(financials.profit),
                        bold: true,
                        valueColor: financials.profit.cents >= 0
                            ? AppColors.positive
                            : AppColors.negative,
                      ),
                      if (financials.profitEstimated != null &&
                          financials.profitEstimated != financials.profit)
                        InfoRow(
                          label: 'Profit (estimated)',
                          value: MoneyFormatter.format(
                            financials.profitEstimated!,
                          ),
                          valueColor: financials.profitEstimated!.cents >= 0
                              ? AppColors.positive
                              : AppColors.negative,
                        ),
                      if (financials.netSales.cents > 0)
                        InfoRow(
                          label: 'Margin',
                          value:
                              '${financials.marginPercent.toStringAsFixed(1)}%',
                        ),
                    ],
                  ),
                ),
                if (role.canManageOperations &&
                    order.status.allowedNext.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  for (final status in order.status.allowedNext)
                    if (status != OrderStatus.cancelled || role.canCancelOrders)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: OutlinedButton.icon(
                          onPressed: () => _changeStatus(context, ref, status),
                          icon: Icon(_iconFor(status)),
                          label: Text(_labelFor(status)),
                          style: status == OrderStatus.cancelled
                              ? OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.danger,
                                )
                              : null,
                        ),
                      ),
                ],
                const SizedBox(height: 4),
                Card(
                  child: Column(
                    children: [
                      const SectionTitle(
                        'Items',
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                      ),
                      if (data.items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'This order has no items.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        )
                      else
                        for (final item in data.items)
                          ListTile(
                            dense: true,
                            title: Text(item.description),
                            subtitle: Text(
                              '${item.quantity} × ${MoneyFormatter.format(item.unitPrice)}',
                            ),
                            trailing: Text(
                              MoneyFormatter.format(item.lineTotal),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      SectionTitle(
                        'Payments',
                        trailing: role.canManageFinance
                            ? TextButton.icon(
                                onPressed: () =>
                                    _recordPayment(context, ref, financials),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Record'),
                              )
                            : null,
                      ),
                      if (data.payments.isEmpty)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'No payment recorded yet.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        )
                      else
                        for (final payment in data.payments)
                          ListTile(
                            dense: true,
                            leading: Icon(
                              payment.status == 'void'
                                  ? Icons.block
                                  : Icons.check_circle_outline,
                              color: payment.status == 'void'
                                  ? AppColors.textSecondary
                                  : AppColors.success,
                            ),
                            title: Text(
                              '${payment.kind} · ${payment.method}',
                              style: TextStyle(
                                decoration: payment.status == 'void'
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            subtitle: Text(
                              [
                                AppDate.format(payment.paidAt),
                                if (payment.reference != null)
                                  payment.reference!,
                              ].join(' · '),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  MoneyFormatter.format(payment.amount),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (role.canManageFinance &&
                                    payment.status == 'successful')
                                  PopupMenuButton<String>(
                                    onSelected: (value) => _paymentAction(
                                      context,
                                      ref,
                                      value,
                                      payment,
                                    ),
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'refund',
                                        child: Text('Refund'),
                                      ),
                                      if (role.canDeleteRecords)
                                        const PopupMenuItem(
                                          value: 'void',
                                          child: Text('Void'),
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                      if (data.refunds.isNotEmpty) ...[
                        const Divider(height: 1),
                        const SectionTitle(
                          'Refunds',
                          padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                        ),
                        for (final refund in data.refunds)
                          ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.undo,
                              color: AppColors.warning,
                            ),
                            title: Text(refund.reason ?? 'Refund'),
                            subtitle: Text(AppDate.format(refund.refundedAt)),
                            trailing: Text(
                              MoneyFormatter.format(refund.amount),
                              style: const TextStyle(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      SectionTitle(
                        'Production costs',
                        trailing: role.canManageOperations
                            ? TextButton.icon(
                                onPressed: () => _addCost(context, ref),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add'),
                              )
                            : null,
                      ),
                      if (data.costs.isEmpty)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'No production cost recorded.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        )
                      else
                        for (final cost in data.costs)
                          ListTile(
                            dense: true,
                            title: Text(cost.description),
                            subtitle: Text(
                              '${cost.costType} · ${cost.quantity} × '
                              '${MoneyFormatter.format(cost.unitCost)}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  MoneyFormatter.format(cost.amount),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (role.canManageOperations)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    color: AppColors.danger,
                                    onPressed: () =>
                                        _deleteCost(context, ref, cost),
                                  ),
                              ],
                            ),
                          ),
                    ],
                  ),
                ),
                if (data.history.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        const SectionTitle(
                          'Timeline',
                          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                        ),
                        for (final entry in data.history)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.timeline, size: 18),
                            title: Text(
                              entry.fromStatus == null
                                  ? OrderStatus.fromDb(entry.toStatus).label
                                  : '${OrderStatus.fromDb(entry.fromStatus).label} → '
                                        '${OrderStatus.fromDb(entry.toStatus).label}',
                            ),
                            subtitle: Text(
                              [
                                AppDate.formatDateTime(entry.changedAt),
                                if (entry.note != null) entry.note!,
                              ].join(' · '),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  IconData _iconFor(OrderStatus status) => switch (status) {
    OrderStatus.confirmed => Icons.check_circle_outline,
    OrderStatus.inProgress => Icons.play_circle_outline,
    OrderStatus.onHold => Icons.pause_circle_outline,
    OrderStatus.completed => Icons.task_alt,
    OrderStatus.delivered => Icons.local_shipping_outlined,
    OrderStatus.closed => Icons.lock_outline,
    OrderStatus.cancelled => Icons.delete_outline,
    _ => Icons.arrow_forward,
  };

  String _labelFor(OrderStatus status) => switch (status) {
    OrderStatus.confirmed => 'Confirm order',
    OrderStatus.inProgress => 'Start production',
    OrderStatus.onHold => 'Put on hold',
    OrderStatus.completed => 'Mark as completed',
    OrderStatus.delivered => 'Mark as delivered',
    OrderStatus.closed => 'Close order',
    OrderStatus.cancelled => 'Cancel order',
    _ => status.label,
  };

  Future<void> _changeStatus(
    BuildContext context,
    WidgetRef ref,
    OrderStatus status,
  ) async {
    if (status == OrderStatus.cancelled) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Cancel order',
        message:
            'The collected amount has to be refunded before an order can be '
            'cancelled. Continue?',
        confirmLabel: 'Cancel order',
        isDestructive: true,
      );
      if (!confirmed) return;
    }

    try {
      await ref
          .read(orderRepositoryProvider)
          .updateStatus(orderId: orderId, toStatus: status.dbValue);
      ref.invalidate(orderDetailProvider(orderId));
      ref.invalidate(ordersProvider);
      if (!context.mounted) return;
      showAppSnackBar(context, 'Order ${status.label.toLowerCase()}');
    } catch (error) {
      if (!context.mounted) return;
      final message = error is AppException
          ? error.message
          : 'Could not update the order';
      showAppSnackBar(context, message, isError: true);
    }
  }

  Future<void> _recordPayment(
    BuildContext context,
    WidgetRef ref,
    OrderFinancials financials,
  ) async {
    final businessId = ref.read(activeBusinessIdProvider);
    if (businessId == null) return;

    final recorded = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => PaymentSheet(
        orderId: orderId,
        businessId: businessId,
        outstanding: financials.outstandingAmount,
      ),
    );

    if (recorded == true) {
      ref.invalidate(orderDetailProvider(orderId));
    }
  }

  Future<void> _addCost(BuildContext context, WidgetRef ref) async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => OrderCostSheet(orderId: orderId),
    );
    if (added == true) {
      ref.invalidate(orderDetailProvider(orderId));
    }
  }

  Future<void> _deleteCost(
    BuildContext context,
    WidgetRef ref,
    OrderCost cost,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete cost',
      message: 'Remove "${cost.description}" from this order?',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;

    try {
      await ref.read(orderRepositoryProvider).deleteCost(cost.id);
      ref.invalidate(orderDetailProvider(orderId));
    } catch (error) {
      if (!context.mounted) return;
      final message = error is AppException
          ? error.message
          : 'Could not delete the cost';
      showAppSnackBar(context, message, isError: true);
    }
  }

  Future<void> _paymentAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    PaymentRecord payment,
  ) async {
    if (action == 'refund') {
      await _refund(context, ref, payment);
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: 'Void payment',
      message:
          'The payment is kept for the audit trail but no longer counts towards '
          'the balance.',
      confirmLabel: 'Void',
      isDestructive: true,
    );
    if (!confirmed) return;

    try {
      await ref
          .read(paymentRepositoryProvider)
          .voidPayment(paymentId: payment.id);
      ref.invalidate(orderDetailProvider(orderId));
    } catch (error) {
      if (!context.mounted) return;
      final message = error is AppException
          ? error.message
          : 'Could not void the payment';
      showAppSnackBar(context, message, isError: true);
    }
  }

  Future<void> _refund(
    BuildContext context,
    WidgetRef ref,
    PaymentRecord payment,
  ) async {
    final amountController = TextEditingController(text: payment.amount.plain);
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Refund'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AmountField(label: 'Amount', controller: amountController),
            const SizedBox(height: 12),
            AppTextField(label: 'Reason', controller: reasonController),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Refund'),
          ),
        ],
      ),
    );

    final amount = Money.tryParse(amountController.text);
    final reason = reasonController.text.trim();
    amountController.dispose();
    reasonController.dispose();

    if (confirmed != true || amount == null || !context.mounted) return;

    try {
      await ref
          .read(paymentRepositoryProvider)
          .recordRefund(paymentId: payment.id, amount: amount, reason: reason);
      ref.invalidate(orderDetailProvider(orderId));
      if (!context.mounted) return;
      showAppSnackBar(context, 'Refund recorded');
    } catch (error) {
      if (!context.mounted) return;
      final message = error is AppException
          ? error.message
          : 'Could not record the refund';
      showAppSnackBar(context, message, isError: true);
    }
  }

  Future<void> _onMenu(
    BuildContext context,
    WidgetRef ref,
    String action,
    OrderDetail detail,
  ) async {
    final businessName =
        ref.read(activeMembershipProvider)?.name ?? 'MTO Finance';
    try {
      final bytes = await DocumentPdf.buildOrder(
        businessName: businessName,
        detail: detail,
      );
      final filename = '${detail.order.orderNo}.pdf';

      if (action == 'print') {
        await ExportService.printPdf(bytes: bytes, filename: filename);
      } else {
        await ExportService.sharePdf(bytes: bytes, filename: filename);
      }
    } catch (error) {
      if (!context.mounted) return;
      showAppSnackBar(context, 'Could not create the PDF', isError: true);
    }
  }
}
