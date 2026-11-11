import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart';
import 'core/config/env.dart';
import 'core/localization/app_localizations.dart';
import 'core/localization/locale_provider.dart';
import 'core/supabase/supabase_client.dart';
import 'core/theme/app_theme.dart';
import 'features/business/providers/business_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!Env.isConfigured) {
    runApp(const ConfigurationErrorApp());
    return;
  }

  try {
    await AppSupabase.initialize();
  } catch (error) {
    runApp(ConfigurationErrorApp(message: error.toString()));
    return;
  }

  runApp(const ProviderScope(child: MtoFinanceApp()));
}

class MtoFinanceApp extends ConsumerStatefulWidget {
  const MtoFinanceApp({super.key});

  @override
  ConsumerState<MtoFinanceApp> createState() => _MtoFinanceAppState();
}

class _MtoFinanceAppState extends ConsumerState<MtoFinanceApp> {
  @override
  void initState() {
    super.initState();
    // Restores the business that was used last time.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeBusinessIdProvider.notifier).restore();
      ref.read(appLocaleProvider.notifier).restore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(appLocaleProvider);

    return MaterialApp.router(
      title: 'MTO Finance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}

/// Shown when the Supabase configuration is missing. The app cannot continue
/// without it, so this screen explains exactly what has to be provided.
class ConfigurationErrorApp extends StatelessWidget {
  const ConfigurationErrorApp({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.settings_suggest_outlined, size: 46),
                const SizedBox(height: 18),
                Text(
                  'MTO Finance needs its Supabase configuration',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  message ?? Env.missingConfigurationMessage,
                  style: const TextStyle(height: 1.45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
