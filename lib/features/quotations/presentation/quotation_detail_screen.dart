import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/quotation_status.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/export/document_pdf.dart';
import '../../../core/export/export_service.dart';
import '../../../core/money/money_format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/info_row.dart';
import '../../../shared/widgets/section_title.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../business/providers/business_providers.dart';
import '../domain/quotation.dart';
import '../providers/quotation_providers.dart';

class QuotationDetailScreen extends ConsumerWidget {
  const QuotationDetailScreen({super.key, required this.quotationId});

  final String quotationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotation = ref.watch(quotationDetailProvider(quotationId));
    final role = ref.watch(currentRoleProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.translate('Quotation')),
        actions: [
          quotation.maybeWhen(
            data: (data) => Row(
              children: [
                if (role.canManageOperations && data.status.allowsEditing)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () =>
                        context.push('/app/quotations/${data.id}/edit'),
                  ),
                PopupMenuButton<String>(
                  onSelected: (value) => _onMenu(context, ref, value, data),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'print',
                      child: Text(
                        context.l10n.translate('Print / save as PDF'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'share',
                      child: Text(context.l10n.translate('Share PDF')),
                    ),
                  ],
                ),
              ],
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: quotation.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(quotationDetailProvider(quotationId)),
        ),
        data: (data) {
          return ListView(
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
                            data.quotationNo,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        StatusChip.quotation(data.status),
                      ],
                    ),
                    const SizedBox(height: 12),
                    InfoRow(
                      label: 'Customer',
                      value: data.customerName,
                      icon: Icons.person_outline,
                    ),
                    InfoRow(
                      label: 'Issued',
                      value: AppDate.format(data.createdAt),
                      icon: Icons.event_outlined,
                    ),
                    InfoRow(
                      label: 'Valid until',
                      value: data.validUntil == null
                          ? '—'
                          : AppDate.format(data.validUntil),
                      icon: Icons.timer_outlined,
                    ),
                    InfoRow(
                      label: 'Total',
                      value: MoneyFormatter.format(data.totalAmount),
                      icon: Icons.payments_outlined,
                      bold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
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
                            'This quotation has no items.',
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
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
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
                      value: MoneyFormatter.format(data.subtotal),
                    ),
                    InfoRow(
                      label: 'Discount',
                      value: '- ${MoneyFormatter.format(data.discountAmount)}',
                    ),
                    const Divider(height: 18),
                    InfoRow(
                      label: 'Total',
                      value: MoneyFormatter.format(data.totalAmount),
                      bold: true,
                    ),
                    if (data.notes != null && data.notes!.isNotEmpty) ...[
                      const Divider(height: 18),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(data.notes!),
                      ),
                    ],
                  ],
                ),
              ),
              if (role.canManageOperations &&
                  data.status.allowedNext.isNotEmpty) ...[
                const SizedBox(height: 16),
                for (final status in data.status.allowedNext)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton.icon(
                      onPressed: () => _changeStatus(context, ref, status),
                      icon: Icon(_iconFor(status)),
                      label: Text(_labelFor(status)),
                      style: status == QuotationStatus.cancelled
                          ? OutlinedButton.styleFrom(
                              foregroundColor: AppColors.danger,
                            )
                          : null,
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  IconData _iconFor(QuotationStatus status) => switch (status) {
    QuotationStatus.sent => Icons.send_outlined,
    QuotationStatus.accepted => Icons.check_circle_outline,
    QuotationStatus.rejected => Icons.cancel_outlined,
    QuotationStatus.expired => Icons.timer_off_outlined,
    QuotationStatus.cancelled => Icons.delete_outline,
    _ => Icons.arrow_forward,
  };

  String _labelFor(QuotationStatus status) => switch (status) {
    QuotationStatus.sent => 'Mark as sent',
    QuotationStatus.accepted => 'Mark as accepted',
    QuotationStatus.rejected => 'Mark as rejected',
    QuotationStatus.expired => 'Mark as expired',
    QuotationStatus.cancelled => 'Cancel quotation',
    _ => status.label,
  };

  Future<void> _changeStatus(
    BuildContext context,
    WidgetRef ref,
    QuotationStatus status,
  ) async {
    try {
      await ref
          .read(quotationRepositoryProvider)
          .setStatus(quotationId: quotationId, status: status.dbValue);
      ref.invalidate(quotationDetailProvider(quotationId));
      ref.invalidate(quotationsProvider);
      if (!context.mounted) return;
      showAppSnackBar(context, 'Quotation ${status.label.toLowerCase()}');
    } catch (error) {
      if (!context.mounted) return;
      final message = error is AppException
          ? error.displayMessage
          : 'Could not update the quotation';
      showAppSnackBar(context, message, isError: true);
    }
  }

  Future<void> _onMenu(
    BuildContext context,
    WidgetRef ref,
    String action,
    Quotation quotation,
  ) async {
    final businessName =
        ref.read(activeMembershipProvider)?.name ?? 'MTO Finance';
    try {
      final bytes = await DocumentPdf.buildQuotation(
        businessName: businessName,
        quotation: quotation,
      );
      final filename = '${quotation.quotationNo}.pdf';

      if (action == 'print') {
        await ExportService.printPdf(bytes: bytes, filename: filename);
      } else {
        await ExportService.sharePdf(bytes: bytes, filename: filename);
      }
    } catch (error) {
      if (!context.mounted) return;
      showAppSnackBar(context, errorDisplayMessage(error), isError: true);
    }
  }
}
