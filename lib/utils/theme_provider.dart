import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  static const _key = 'isDarkMode';

  bool _isDark = false;
  bool get isDark => _isDark;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool(_key) ?? false;
    notifyListeners();
  }

  Future<void> toggle() async {
    await setDark(!_isDark);
  }

  Future<void> setDark(bool val) async {
    _isDark = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, val);
    notifyListeners();
  }
}
