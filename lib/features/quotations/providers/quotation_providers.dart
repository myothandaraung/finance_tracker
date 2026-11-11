import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../business/providers/business_providers.dart';
import '../../customers/providers/customer_providers.dart';
import '../data/quotation_repository.dart';
import '../domain/quotation.dart';

final quotationRepositoryProvider = Provider<QuotationRepository>((ref) {
  return QuotationRepository(ref.watch(supabaseClientProvider));
});

/// Filters applied to the quotation list.
class QuotationFilter {
  const QuotationFilter({this.status, this.search = ''});

  final String? status;
  final String search;

  QuotationFilter copyWith({
    String? status,
    bool clearStatus = false,
    String? search,
  }) {
    return QuotationFilter(
      status: clearStatus ? null : (status ?? this.status),
      search: search ?? this.search,
    );
  }
}

class QuotationFilterNotifier extends Notifier<QuotationFilter> {
  @override
  QuotationFilter build() => const QuotationFilter();

  void setStatus(String? status) {
    state = status == null
        ? state.copyWith(clearStatus: true)
        : state.copyWith(status: status);
  }

  void setSearch(String search) => state = state.copyWith(search: search);
}

final quotationFilterProvider =
    NotifierProvider<QuotationFilterNotifier, QuotationFilter>(
      QuotationFilterNotifier.new,
    );

/// Quotations of the active business, filtered.
final quotationsProvider = FutureProvider<List<Quotation>>((ref) async {
  final businessId = ref.watch(activeBusinessIdProvider);
  if (businessId == null) return const [];

  final filter = ref.watch(quotationFilterProvider);
  final repository = ref.watch(quotationRepositoryProvider);
  final rows = await repository.listQuotationRows(
    businessId,
    status: filter.status,
  );

  final customers = await ref
      .watch(customerRepositoryProvider)
      .listCustomers(businessId);
  final names = {for (final customer in customers) customer.id: customer.name};

  final quotations = rows
      .map(
        (row) => Quotation.fromJson(
          row,
          customerName: names[row['customer_id']] ?? 'Unknown customer',
        ),
      )
      .toList();

  final search = filter.search.trim().toLowerCase();
  if (search.isEmpty) return quotations;

  return quotations
      .where(
        (quotation) =>
            quotation.quotationNo.toLowerCase().contains(search) ||
            quotation.customerName.toLowerCase().contains(search),
      )
      .toList();
});

/// A quotation with its line items.
final quotationDetailProvider = FutureProvider.family<Quotation, String>((
  ref,
  quotationId,
) async {
  final businessId = ref.watch(activeBusinessIdProvider);
  if (businessId == null) {
    throw StateError('No business selected');
  }

  final repository = ref.watch(quotationRepositoryProvider);
  final row = await repository.selectRow(
    'quotations',
    filters: {'id': quotationId, 'business_id': businessId},
  );
  if (row == null) throw StateError('Quotation not found');

  final items = await repository.listItems(quotationId);
  final customer = await ref
      .watch(customerRepositoryProvider)
      .findCustomer(businessId, (row['customer_id'] as String?) ?? '');

  return Quotation.fromJson(
    row,
    customerName: customer?.name ?? 'Unknown customer',
    items: items,
  );
});
