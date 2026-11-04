/// Build-time configuration.
///
/// Values are injected at compile time:
///
/// ```sh
/// flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co \
///              --dart-define=SUPABASE_ANON_KEY=eyJ...
/// ```
///
/// `tool/run_dev.ps1` reads `tool/env.local.json` and passes them for you.
///
/// Only the publishable (anon) key may ever be embedded here. The service
/// role key is a secret and must never reach the client.
/// 
/// 
class Env {
  const Env._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// True when the app has enough configuration to talk to Supabase.
  static bool get isConfigured =>
      supabaseUrl.startsWith('http') && supabaseAnonKey.isNotEmpty;

  static String get missingConfigurationMessage =>
      'Supabase is not configured.\n\n'
      'Run the app with:\n'
      '--dart-define=SUPABASE_URL=<project url>\n'
      '--dart-define=SUPABASE_ANON_KEY=<anon key>\n\n'
      'or fill in tool/env.local.json and use tool/run_dev.ps1.';
}
