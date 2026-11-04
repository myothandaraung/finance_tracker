/// Currency symbols used by the app. The database stores an ISO code per
/// business; this maps the most common ones to a display symbol.
String currencySymbol(String? currencyCode) {
  switch (currencyCode) {
    case 'PHP':
      return '₱';
    case 'USD':
      return '\$';
    case 'EUR':
      return '€';
    case 'JPY':
      return '¥';
    default:
      return '${currencyCode ?? 'MMK'} ';
  }
}
