# Myanmar Kyat (MMK) Currency Fix Plan

## Problem
The app defaults to PHP (₱) currency symbol in `AmountField`, but the business default currency is MMK (Myanmar Kyat). Amount inputs and displays don't respect the business's configured currency.

## Current State
- `BusinessMembership.currencyCode` defaults to `'MMK'`
- `currencySymbol()` function in `currency.dart` returns `'Ks '` for MMK
- `MoneyFormatter.format()` defaults to `'Ks'` symbol
- `AmountField` defaults to `'₱'` (PHP) - **mismatch**
- `Money.tryParse()` already handles `'Ks', 'ks', 'MMK', 'mmk'` input

## Solution

### 1. Create a currency symbol provider
Add a provider that derives the currency symbol from the active business membership:
```dart
// In business_providers.dart or new currency_providers.dart
final activeCurrencySymbolProvider = Provider<String>((ref) {
  final membership = ref.watch(activeMembershipProvider);
  return currencySymbol(membership?.currencyCode); // Returns 'Ks ' for MMK
});
```

### 2. Update `AmountField` to auto-detect business currency
Modify `AmountField` in `app_text_field.dart` to:
- Accept optional `currencySymbol` parameter (keep for override)
- If not provided, read from `activeCurrencySymbolProvider` via `ref.watch`
- Make it a `ConsumerWidget` to access providers

### 3. Update `MoneyFormatter.format()` calls
Ensure all display formatting uses the business currency symbol. Currently some calls pass explicit symbol, others rely on default.

### 4. Update all `AmountField` usages
Forms using `AmountField` (Product, Order, Quotation, Material, Expense, Payment, Document Editor) will automatically get correct currency.

## Files to Modify

1. **`lib/features/business/providers/business_providers.dart`** - Add `activeCurrencySymbolProvider`
2. **`lib/shared/widgets/app_text_field.dart`** - Convert `AmountField` to `ConsumerWidget`, auto-detect currency
3. **`lib/core/money/money_format.dart`** - Verify `format()` handles symbol correctly (already does)
4. **`lib/shared/widgets/document_editor.dart`** - `LineEditor` uses `AmountField`, will auto-update

## Validation
- Create business with MMK currency → amount fields show "Ks" prefix
- Create business with PHP currency → amount fields show "₱" prefix
- Input "Ks 1,234.50" or "1234.50" → parses correctly
- Display formatting shows correct symbol in lists, totals, reports

## Out of Scope
- Currency conversion (app stores single currency per business)
- Historical currency changes (currency is per-business setting)
- Multi-currency businesses