import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:projetonovo/core/rede/api_client.dart';
import 'package:projetonovo/features/carreira/carreira_page.dart';
import 'package:projetonovo/models/auth_model.dart';
import 'package:provider/provider.dart';

CarreiraRepositorio _repo(Object resposta) => CarreiraRepositorio(
      api: ApiClient(temInternet: () async => true, cliente: MockClient((_) async => http.Response(jsonEncode(resposta), 200,
          headers: {'content-type': 'application/json; charset=utf-8'}))),
      matricula: '1',
      senhaMd5: 'x',
      url: Uri.parse('https://teste.invalid/carreira.php'),
    );

void main() {
  setUp(() => CarreiraRepositorio.emUso.value = null);
  testWidgets('mostra os marcos por ano e a seção que falhou com código', (t) async {
    await t.pumpWidget(ChangeNotifierProvider(create: (_) => Auth(), child: MaterialApp(
      home: CarreiraPage(
          repositorio: _repo({
        'code': 1,
        'eventos': [
          {'data': '2019-03-11', 'tipo': 'incorporacao', 'titulo': 'Incorporação na PMRR'},
          {'data': '2024-12-20', 'tipo': 'promocao', 'titulo': 'Promoção a Cabo (QPPM)', 'detalhe': 'BG 230/2024'},
        ],
        'falhas': ['escolaridade'],
      })),
    )));
    await t.pumpAndSettle();
    expect(find.text('2024'), findsOneWidget);
    expect(find.text('2019'), findsOneWidget);
    expect(find.text('Promoção a Cabo (QPPM)'), findsOneWidget);
    expect(find.textContaining('CR-ESCOLARIDADE'), findsOneWidget);
  });

  testWidgets('sessão inválida vira tela de erro com código CR-', (t) async {
    await t.pumpWidget(ChangeNotifierProvider(create: (_) => Auth(), child: MaterialApp(
        home: CarreiraPage(repositorio: _repo({'code': 0, 'erro': 'SESSAO_INVALIDA', 'message': 'Saia e entre.'})))));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('CR-SESSAO-INVALIDA'), findsWidgets);
  });
}
