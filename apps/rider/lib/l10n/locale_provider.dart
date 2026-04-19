import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'strings.dart';

class LocaleProvider extends ChangeNotifier {
  String _locale;

  LocaleProvider(this._locale);

  String get locale => _locale;
  bool get isSet => _locale.isNotEmpty;

  static Future<LocaleProvider> load() async {
    final prefs = await SharedPreferences.getInstance();
    return LocaleProvider(prefs.getString('app_locale') ?? '');
  }

  Future<void> setLocale(String locale) async {
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_locale', locale);
  }

  String t(String key) {
    final map = AppStrings.of(_locale.isEmpty ? 'pt' : _locale);
    return map[key] ?? AppStrings.of('pt')[key] ?? key;
  }
}
