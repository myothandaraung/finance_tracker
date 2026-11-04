import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_format.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../business/providers/business_providers.dart';
import '../providers/payment_providers.dart';
import '../../expenses/providers/expense_providers.dart';

/// Collects a payment for an order.
///
/// The submission carries an idempotency key, so a failed request that is
/// retried can never be recorded twice.
class PaymentSheet extends ConsumerStatefulWidget {
  const PaymentSheet({
    super.key,
    required this.orderId,
    required this.businessId,
    required this.outstanding,
  });

  final String orderId;
  final String businessId;
  final Money outstanding;

  @override
  ConsumerState<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<PaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();

  String _kind = 'installment';
  String _method = 'cash';
  DateTime _paidAt = DateTime.now();
  String? _receiptPath;
  bool _isSaving = false;
  bool _isUploading = false;

  late final String _idempotencyKey = const Uuid().v4();

  static const _kinds = [
    ('deposit', 'Deposit'),
    ('installment', 'Installment'),
    ('final', 'Final payment'),
    ('adjustment', 'Adjustment'),
  ];

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.outstanding.plain;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (image == null) return;

    setState(() => _isUploading = true);
    try {
      final bytes = await image.readAsBytes();
      final extension = image.path.split('.').last;
      final path = '${widget.businessId}/${widget.orderId}/'
          '${DateTime.now().millisecondsSinceEpoch}.$extension';

      await Supabase.instance.client.storage
          .from(AppBuckets.receipts)
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      if (!mounted) return;
      setState(() => _receiptPath = path);
      showAppSnackBar(context, 'Receipt attached');
    } catch (error) {
      if (!mounted) return;
      final message = error is AppException
          ? error.message
          : 'Could not upload the receipt';
      showAppSnackBar(context, message, isError: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final amount = Money.tryParse(_amountController.text);
    if (amount == null || amount.cents <= 0) {
      showAppSnackBar(context, 'Enter an amount above zero', isError: true);
      return;
    }

    final allowOverpayment = amount.cents > widget.outstanding.cents;
    if (allowOverpayment) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Amount above the balance',
        message:
            'The outstanding balance is ${MoneyFormatter.format(widget.outstanding)}. '
            'Only an owner can accept a larger payment.',
        confirmLabel: 'Record anyway',
        isDestructive: true,
      );
      if (!confirmed) return;
    }

    setState(() => _isSaving = true);
    try {
      final result = await ref.read(paymentRepositoryProvider).recordPayment(
            orderId: widget.orderId,
            amount: amount,
            kind: _kind,
            method: _method,
            reference: _referenceController.text.trim(),
            paidAt: _paidAt,
            idempotencyKey: _idempotencyKey,
            receiptPath: _receiptPath,
            allowOverpayment: allowOverpayment,
          );

      if (!mounted) return;
      showAppSnackBar(
        context,
        result.isDuplicate
            ? 'This payment was already recorded'
            : 'Payment recorded. Outstanding ${MoneyFormatter.format(result.outstanding)}',
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      final message = error is AppException
          ? error.message
          : 'Could not record the payment';
      showAppSnackBar(context, message, isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final methods = ref.watch(paymentMethodsProvider).value ?? const [];
    final role = ref.watch(currentRoleProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Record payment',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Outstanding balance ${MoneyFormatter.format(widget.outstanding)}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                initialValue: _kind,
                decoration: const InputDecoration(labelText: 'Payment type'),
                items: [
                  for (final kind in _kinds)
                    DropdownMenuItem(value: kind.$1, child: Text(kind.$2)),
                ],
                onChanged: (value) => setState(() => _kind = value ?? 'installment'),
              ),
              const SizedBox(height: 12),
              AmountField(
                label: 'Amount',
                controller: _amountController,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _method,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Method'),
                items: [
                  const DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  const DropdownMenuItem(value: 'bank', child: Text('Bank transfer')),
                  for (final method in methods)
                    DropdownMenuItem(
                      value: method.name,
                      child: Text(method.name),
                    ),
                ],
                onChanged: (value) => setState(() => _method = value ?? 'cash'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('Paid on'),
                subtitle: Text(AppDate.formatDateTime(_paidAt)),
                trailing: TextButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now(),
                      initialDate: _paidAt,
                    );
                    if (date == null || !context.mounted) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_paidAt),
                    );
                    if (!context.mounted) return;
                    setState(() {
                      _paidAt = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time?.hour ?? _paidAt.hour,
                        time?.minute ?? _paidAt.minute,
                      );
                    });
                  },
                  child: const Text('Change'),
                ),
              ),
              const SizedBox(height: 8),
              AppTextField(
                label: 'Reference',
                controller: _referenceController,
                hint: 'Receipt or transaction number',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isUploading ? null : _pickReceipt,
                icon: _isUploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.attach_file),
                label: Text(
                  _receiptPath == null ? 'Attach receipt' : 'Receipt attached',
                ),
              ),
              const SizedBox(height: 20),
              AppButton(
                label: 'Save payment',
                icon: Icons.check,
                isLoading: _isSaving,
                onPressed: role.canManageFinance ? _save : null,
              ),
              if (!role.canManageFinance) ...[
                const SizedBox(height: 8),
                const Text(
                  'Only an owner or an accountant can record payments.',
                  style: TextStyle(color: AppColors.danger, fontSize: 12.5),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
