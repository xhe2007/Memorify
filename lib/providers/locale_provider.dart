import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  static const _key = 'app_locale';
  late SharedPreferences _prefs;

  String _locale = '中文';
  String get locale => _locale;

  bool get isEnglish => _locale == 'English';
  bool get isChinese => _locale == '中文';

  Future<void> loadLocale() async {
    _prefs = await SharedPreferences.getInstance();
    _locale = _prefs.getString(_key) ?? '中文';
    notifyListeners();
  }

  Future<void> setLocale(String newLocale) async {
    if (_locale != newLocale) {
      _locale = newLocale;
      await _prefs.setString(_key, newLocale);
      notifyListeners();
    }
  }
}