import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocaleNotifier extends Notifier<Locale> {
  static const _preferenceKey = 'app_language';

  @override
  Locale build() => const Locale('en');

  Future<void> restore() async {
    final preferences = await SharedPreferences.getInstance();
    final code = preferences.getString(_preferenceKey);
    if (code == 'en' || code == 'my') state = Locale(code!);
  }

  Future<void> select(String code) async {
    if (code != 'en' && code != 'my') return;
    state = Locale(code);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, code);
  }
}

final appLocaleProvider = NotifierProvider<AppLocaleNotifier, Locale>(
  AppLocaleNotifier.new,
);
