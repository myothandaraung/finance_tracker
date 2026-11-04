/// Builds CSV files for the report exports.
///
/// The encoder follows RFC 4180: fields containing a comma, a quote or a line
/// break are wrapped in double quotes and inner quotes are doubled.
class CsvExporter {
  const CsvExporter._();

  /// Encodes rows; the first row is used as the header.
  static String encode(List<List<dynamic>> rows) {
    final buffer = StringBuffer();
    for (var index = 0; index < rows.length; index++) {
      buffer.write(_encodeRow(rows[index]));
      if (index < rows.length - 1) buffer.write('\r\n');
    }
    return buffer.toString();
  }

  static String _encodeRow(List<dynamic> row) {
    return row.map(_encodeField).join(',');
  }

  static String _encodeField(dynamic field) {
    final text = field?.toString() ?? '';
    if (!text.contains(RegExp('[,"\r\n]'))) return text;
    return '"${text.replaceAll('"', '""')}"';
  }
}
