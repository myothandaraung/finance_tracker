import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

/// Saving and sharing of the documents produced by the app.
class ExportService {
  const ExportService._();

  /// Opens the platform print dialog, which also allows saving the document
  /// as a PDF file.
  static Future<void> printPdf({
    required Uint8List bytes,
    required String filename,
  }) async {
    await Printing.layoutPdf(
      name: filename,
      onLayout: (_) async => bytes,
    );
  }

  /// Shares the PDF through the system share sheet.
  static Future<void> sharePdf({
    required Uint8List bytes,
    required String filename,
  }) async {
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  /// Writes a CSV file into the app documents folder and returns its path.
  ///
  /// The file stays on the device; the user can open it with any spreadsheet
  /// application. The path is shown so it can be shared manually.
  static Future<String> saveCsv({
    required String content,
    required String filename,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final exportDirectory = Directory('${directory.path}/exports');
    if (!exportDirectory.existsSync()) {
      await exportDirectory.create(recursive: true);
    }

    final file = File('${exportDirectory.path}/$filename');
    await file.writeAsString(content);
    return file.path;
  }
}
