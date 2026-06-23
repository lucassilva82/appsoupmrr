import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Três estados possíveis para o tema do app.
enum AppThemeMode {
  /// Segue automaticamente o tema do sistema operacional.
  auto,

  /// Sempre modo escuro, independente do sistema.
  dark,

  /// Sempre modo claro, independente do sistema.
  light,
}

class ThemeProvider with ChangeNotifier, WidgetsBindingObserver {
  static const _key = 'appThemeMode';
  static const _legacyKey = 'isDarkMode';

  AppThemeMode _mode = AppThemeMode.auto;

  /// Modo atual selecionado pelo usuário.
  AppThemeMode get mode => _mode;

  ThemeProvider() {
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Notifica quando o sistema troca de claro/escuro (apenas em modo auto).
  @override
  void didChangePlatformBrightness() {
    if (_mode == AppThemeMode.auto) {
      notifyListeners();
    }
  }

  /// Se o tema efetivo atual é escuro (considerando modo auto + sistema).
  bool get isDark {
    switch (_mode) {
      case AppThemeMode.auto:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
      case AppThemeMode.dark:
        return true;
      case AppThemeMode.light:
        return false;
    }
  }

  /// Valor a ser passado para [MaterialApp.themeMode].
  ThemeMode get themeMode {
    switch (_mode) {
      case AppThemeMode.auto:
        return ThemeMode.system;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.light:
        return ThemeMode.light;
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    // Lê a chave nova primeiro.
    final saved = prefs.getString(_key);
    if (saved != null) {
      _mode = _parseMode(saved);
    } else {
      // Migração da chave legada (bool isDarkMode → AppThemeMode).
      final legacy = prefs.getBool(_legacyKey);
      if (legacy == true) {
        _mode = AppThemeMode.dark;
        await prefs.setString(_key, 'dark');
      } else {
        // Sem preferência anterior → automático.
        _mode = AppThemeMode.auto;
      }
    }

    notifyListeners();
  }

  AppThemeMode _parseMode(String s) {
    switch (s) {
      case 'dark':
        return AppThemeMode.dark;
      case 'light':
        return AppThemeMode.light;
      default:
        return AppThemeMode.auto;
    }
  }

  /// Define o modo do tema e persiste a preferência.
  Future<void> setMode(AppThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
    notifyListeners();
  }

  /// Compat legado: alterna entre claro e escuro (sem passar por auto).
  Future<void> toggle() async {
    await setMode(isDark ? AppThemeMode.light : AppThemeMode.dark);
  }
}
