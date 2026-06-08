import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class Store {
  static Future<String?> getString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    String? value = prefs.getString(key);
    print('[DEBUG] Store.getString($key) retornou: $value');
    return value;
  }

  static Future<void> saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    print('[DEBUG] Store.saveString($key) salvando: $value');
    await prefs.setString(key, value);
  }

  static Future<Map<String, dynamic>> getMap(String key) async {
    final data = await getString(key);
    if (data == null) return {};
    return json.decode(data) as Map<String, dynamic>;
  }

  static Future<void> saveMap(String key, Map<String, dynamic> map) async {
    // Salva o map como JSON
    await saveString(key, jsonEncode(map));
  }
}
