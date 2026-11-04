import 'package:supabase_flutter/supabase_flutter.dart';

/// Application level error carrying a stable [code] and the HTTP
/// [statusCode] returned by the API so the UI can react differently to a
/// permission problem, a duplicate key and a validation error.
class AppException implements Exception {
  const AppException(
    this.message, {
    this.code,
    this.statusCode,
    this.details,
  });

  final String message;
  final String? code;
  final int? statusCode;
  final Object? details;

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
      return AppException(
        error.message,
        code: error.code,
      );
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
}
