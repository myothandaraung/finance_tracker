import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// Storage bucket names. Both buckets are private; files are read through
/// signed URLs.
class AppBuckets {
  const AppBuckets._();

  static const String receipts = 'receipts';
  static const String productImages = 'product-images';
}

/// Thin wrapper around the Supabase client bootstrap.
class AppSupabase {
  const AppSupabase._();

  static Future<void> initialize() async {
    if (!Env.isConfigured) {
      throw StateError(Env.missingConfigurationMessage);
    }
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
