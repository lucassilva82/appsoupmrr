import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projetonovo/core/log/iniciar_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// O log conta o tema que aparece na tela, não o do sistema (25/10/2026).
void main() {
  Future<Map<String, String>> com(String? salvo, Brightness sistema) async {
    SharedPreferences.setMockInitialValues({if (salvo != null) 'appThemeMode': salvo});
    return temaParaLog(sistema, prefs: await SharedPreferences.getInstance());
  }

  test('escolha do militar vence o sistema', () async {
    expect(await com('light', Brightness.dark), {'tema': 'claro', 'escolha': 'claro'});
    expect(await com('dark', Brightness.light), {'tema': 'escuro', 'escolha': 'escuro'});
  });

  test('automático (ou nada salvo) segue o sistema', () async {
    expect(await com('auto', Brightness.dark), {'tema': 'escuro', 'escolha': 'auto'});
    expect(await com(null, Brightness.light), {'tema': 'claro', 'escolha': 'auto'});
  });
}
