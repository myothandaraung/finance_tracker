import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/money/money.dart';

/// Text field with a label, optional prefix and validation support.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.enabled = true,
    this.onChanged,
    this.validator,
    this.prefixText,
    this.suffixText,
    this.autofocus = false,
    this.inputFormatters,
    this.onSubmitted,
    this.obscureText = false,
    this.suffixIcon,
    this.helperText,
    this.autofillHints,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int maxLines;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final String? prefixText;
  final String? suffixText;
  final bool autofocus;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? helperText;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: maxLines,
      autofocus: autofocus,
      onChanged: onChanged,
      validator: validator,
      onFieldSubmitted: onSubmitted,
      inputFormatters: inputFormatters,
      obscureText: obscureText,
      autofillHints: autofillHints,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        suffixText: suffixText,
        suffixIcon: suffixIcon,
        helperText: helperText,
      ),
    );
  }
}

/// Money input. Accepts `1234.50` and renders the parsed value.
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.enabled = true,
    this.onChanged,
    this.validator,
    this.autofocus = false,
    this.currencySymbol = '₱',
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final bool enabled;
  final ValueChanged<Money?>? onChanged;
  final String? Function(String?)? validator;
  final bool autofocus;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      onChanged: (value) => onChanged?.call(Money.tryParse(value)),
      validator: (value) {
        final base = validator?.call(value);
        if (base != null) return base;
        if (value == null || value.trim().isEmpty) return 'Enter an amount';
        if (Money.tryParse(value) == null) {
          return 'Enter a valid amount (max 2 decimals)';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: '$currencySymbol ',
      ),
    );
  }
}

/// Numeric field for quantities (up to 3 decimals).
class QuantityField extends StatelessWidget {
  const QuantityField({
    super.key,
    required this.label,
    this.controller,
    this.validator,
    this.onChanged,
  });

  final String label;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (value) => onChanged?.call(double.tryParse(value) ?? 0),
      validator: (value) {
        final base = validator?.call(value);
        if (base != null) return base;
        final parsed = double.tryParse(value ?? '');
        if (parsed == null || parsed <= 0) return 'Enter a quantity above 0';
        return null;
      },
      decoration: InputDecoration(labelText: label),
    );
  }
}
