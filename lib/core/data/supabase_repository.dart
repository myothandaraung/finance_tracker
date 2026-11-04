import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_exception.dart';

/// Thin base class for the feature repositories.
///
/// It centralises the two things every repository needs: the Supabase client
/// and the conversion of Postgrest/Auth errors into [AppException].
abstract class SupabaseRepository {
  const SupabaseRepository(this.client);

  final SupabaseClient client;

  /// Calls an RPC and returns the decoded json object.
  ///
  /// Every RPC in this project returns `jsonb`, so the result is a map.
  Future<Map<String, dynamic>> callRpc(
    String function, {
    Map<String, dynamic> params = const {},
  }) async {
    try {
      final result = await client.rpc(function, params: params);
      if (result is Map<String, dynamic>) return result;
      if (result is List && result.isNotEmpty && result.first is Map) {
        return Map<String, dynamic>.from(result.first as Map);
      }
      return const {};
    } catch (error) {
      // ignore: avoid_print
      print('RPC $function failed: $error params=$params');
      throw AppException.fromSupabase(error);
    }
  }

  /// Calls an RPC that returns a jsonb array.
  Future<List<Map<String, dynamic>>> callRpcList(
    String function, {
    Map<String, dynamic> params = const {},
  }) async {
    try {
      final result = await client.rpc(function, params: params);
      if (result is List) {
        return result
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
      if (result is Map<String, dynamic>) {
        return [result];
      }
      return const [];
    } catch (error) {
      // ignore: avoid_print
      print('RPC $function failed: $error params=$params');
      throw AppException.fromSupabase(error);
    }
  }

  /// Reads rows from a table, converting errors on the way out.
  Future<List<Map<String, dynamic>>> selectRows(
    String table, {
    Map<String, dynamic> filters = const {},
    String? orderBy,
    bool ascending = false,
    int? limit,
  }) async {
    try {
      return await buildQuery(
        table,
        filters: filters,
        orderBy: orderBy,
        ascending: ascending,
        limit: limit,
      );
    } catch (error) {
      // ignore: avoid_print
      print('selectRows failed: $error');
      throw AppException.fromSupabase(error);
    }
  }

  /// Reads a single row, returning `null` when it does not exist.
  Future<Map<String, dynamic>?> selectRow(
    String table, {
    required Map<String, dynamic> filters,
  }) async {
    try {
      return await buildQuery(table, filters: filters).maybeSingle();
    } catch (error) {
      // ignore: avoid_print
      print('selectRow failed: $error');
      throw AppException.fromSupabase(error);
    }
  }

  /// Builds a filtered and ordered query.
  ///
  /// The filters are applied first because the filter builder is the only one
  /// that accepts them; ordering and limiting happen on the resulting
  /// transform builder.
  PostgrestTransformBuilder<PostgrestList> buildQuery(
    String table, {
    Map<String, dynamic> filters = const {},
    String? orderBy,
    bool ascending = false,
    int? limit,
  }) {
    var query = client.from(table).select();

    filters.forEach((column, value) {
      query = query.eq(column, value);
    });

    PostgrestTransformBuilder<PostgrestList> result = query;
    if (orderBy != null) {
      result = result.order(orderBy, ascending: ascending);
    }
    if (limit != null) {
      result = result.limit(limit);
    }
    return result;
  }
}
