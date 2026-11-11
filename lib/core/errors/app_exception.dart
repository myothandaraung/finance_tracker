import 'package:supabase_flutter/supabase_flutter.dart';

/// Application level error carrying a stable [code] and the HTTP
/// [statusCode] returned by the API so the UI can react differently to a
/// permission problem, a duplicate key and a validation error.
class AppException implements Exception {
  const AppException(this.message, {this.code, this.statusCode, this.details});

  final String message;
  final String? code;
  final int? statusCode;
  final Object? details;

  /// A user-facing message that preserves useful API diagnostics without
  /// exposing the verbose exception wrapper produced by the SDK.
  String get displayMessage {
    final parts = <String>[message.trim()];
    final detailText = _formatDetails(details);
    if (detailText != null &&
        detailText.isNotEmpty &&
        detailText.toLowerCase() != message.trim().toLowerCase()) {
      parts.add(detailText);
    }
    if (code != null && code!.trim().isNotEmpty) {
      parts.add('Error code: ${code!.trim()}');
    }
    return parts.where((part) => part.isNotEmpty).join('\n');
  }

  /// Row Level Security rejected the statement (Postgres 42501).
  bool get isPermissionDenied => statusCode == 403 || code == '42501';

  /// The session is missing or expired.
  bool get isAuthenticationError => statusCode == 401;

  /// Unique violation (Postgres 23505).
  bool get isDuplicate => code == '23505';

  /// A business rule rejected the operation (raised by our RPC layer).
  bool get isBusinessRule => code == 'P0001' || code == 'MTO01';

  /// Converts a Supabase/Postgrest error into an [AppException].
  factory AppException.fromSupabase(Object error) {
    if (error is AppException) return error;
    if (error is PostgrestException) {
      return AppException(
        error.message,
        code: error.code,
        details: error.details,
      );
    }
    if (error is AuthException) {
      return AppException(error.message, code: error.code);
    }
    if (error is StorageException) {
      return AppException(
        error.message,
        code: error.statusCode,
        statusCode: int.tryParse(error.statusCode ?? ''),
      );
    }
    return AppException(error.toString());
  }

  @override
  String toString() => message;

  static String? _formatDetails(Object? value) {
    if (value == null) return null;
    if (value is String) {
      final text = value.trim();
      if (text.isEmpty || text.toLowerCase() == 'null') return null;
      return text;
    }
    if (value is Map) {
      return value.entries
          .where((entry) => entry.value != null)
          .map((entry) => '${entry.key}: ${entry.value}')
          .join('\n');
    }
    return value.toString();
  }
}

/// Converts any caught error to the same detailed message used by error pages.
String errorDisplayMessage(Object error) =>
    AppException.fromSupabase(error).displayMessage;
