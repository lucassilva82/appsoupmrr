import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projetonovo/models/auth_model.dart';
import 'package:projetonovo/pages/auth_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bug de 25/10/2026, achado nos logs do painel (33 AP-FATAL em 4 minutos):
/// no login do Android, abrir o teclado fazia o lema "POLÍCIA MILITAR DE
/// RORAIMA" virar um SizedBox de largura infinita dentro do FittedBox da
/// marca, e o Flutter acusava "given an infinite size during layout".
Widget _tela({required double teclado}) => ChangeNotifierProvider<Auth>(
      create: (_) => Auth(),
      child: MaterialApp(
        home: Builder(
          builder: (c) => MediaQuery(
            data: MediaQuery.of(c).copyWith(viewInsets: EdgeInsets.only(bottom: teclado)),
            child: const AuthPage(),
          ),
        ),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => AuthPage.androidParaTeste = null);

  for (final android in [true, false]) {
    testWidgets('login ${android ? 'Android' : 'iOS'}: abrir e fechar o teclado não quebra o layout', (t) async {
      AuthPage.androidParaTeste = android;
      await t.binding.setSurfaceSize(const Size(412, 915));
      await t.pumpWidget(_tela(teclado: 0));
      await t.pump(const Duration(seconds: 2));
      await t.pumpWidget(_tela(teclado: 320));
      for (var i = 0; i < 20; i++) {
        await t.pump(const Duration(milliseconds: 20));
      }
      expect(t.takeException(), isNull);
      await t.pumpWidget(_tela(teclado: 0));
      for (var i = 0; i < 20; i++) {
        await t.pump(const Duration(milliseconds: 20));
      }
      expect(t.takeException(), isNull);
      await t.binding.setSurfaceSize(null);
    });
  }
}
