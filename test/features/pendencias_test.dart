import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:projetonovo/core/erros/falha_app.dart';
import 'package:projetonovo/core/rede/api_client.dart';
import 'package:projetonovo/features/pendencias/pendencias_page.dart';
import 'package:projetonovo/features/pendencias/pendencias_repositorio.dart';
import 'package:projetonovo/models/auth_model.dart';
import 'package:provider/provider.dart';

http.Response _json(Object corpo) =>
    http.Response(jsonEncode(corpo), 200, headers: {'content-type': 'application/json; charset=utf-8'});

PendenciasRepositorio _repo(Object Function(Map<String, String>) responder) => PendenciasRepositorio(
      api: ApiClient(cliente: MockClient((r) async => _json(responder(r.bodyFields))), temInternet: () async => true),
      matricula: '1234567',
      senhaMd5: 'a' * 32,
      url: Uri.parse('https://teste/pendencias.php'),
    );

const _lista = {
  'code': 1,
  'ligados': 2,
  'itens': [
    {'tipo': 'soupm.ciencia_comunicado', 'sistema': 'SouPMRR', 'titulo': 'Ciência pendente: X', 'obrigatoria': true,
     'referencia': 'comunicado:5', 'destino': 'com.central', 'prazo': '2026-10-25T22:39:13-04'},
    {'tipo': 'soupm.certidao_vencendo', 'sistema': 'SouPMRR', 'titulo': 'Sua certidão vence em 2 dias',
     'dispensavel': true, 'referencia': 'certidao:1'},
    {'tipo': 'sigrh.declaracao_bens', 'sistema': 'SIGRH', 'titulo': 'Não foi possível conferir SIGRH',
     'obrigatoria': true, 'referencia': 'erro', 'erro': 'PD-SIGRH-FALHA'},
  ],
};

Widget _app(Widget filho) => ChangeNotifierProvider<Auth>.value(value: Auth(), child: MaterialApp(home: Scaffold(body: filho)));

void main() {
  setUp(() => PendenciasRepositorio.emUso.value = null);

  test('lista lê prazo com fuso, obrigatória, dispensável e o erro da fonte', () async {
    final s = await _repo((_) => _lista).listar();
    expect(s.ligados, 2);
    expect(s.itens.first.prazo, isNotNull);
    expect(s.itens[1].dispensavel, isTrue);
    expect(s.itens.last.erro, 'PD-SIGRH-FALHA', reason: 'fonte que falhou não some');
  });

  test('dispensar tira o item da lista em uso; obrigatória recusada vira PD-', () async {
    final repo = _repo((c) => c['acao'] == 'listar' ? _lista : {'code': 1});
    final s = await repo.listar();
    await repo.dispensar(s.itens[1]);
    expect(PendenciasRepositorio.emUso.value!.itens.map((p) => p.tipo), isNot(contains('soupm.certidao_vencendo')));
    await expectLater(
      _repo((_) => {'code': 0, 'erro': 'NAO_DISPENSAVEL', 'message': 'Obrigatória.'}).dispensar(s.itens.first),
      throwsA(isA<FalhaApp>().having((f) => f.codigo, 'codigo', 'PD-NAO-DISPENSAVEL')),
    );
  });

  // Até 27/10/2026 o bloco sumia sem nenhum tipo ligado, para não afirmar
  // "Sem pendências" sem ninguém ter conferido. O usuário mudou a decisão em
  // 28/10: bloco que aparece e some na abertura tem cara de erro, e ele
  // prefere a afirmação constante.
  testWidgets('sem tipo ligado no painel o bloco continua lá, dizendo que não há nada', (t) async {
    await t.pumpWidget(_app(BlocoPendencias(repositorio: _repo((_) => {'code': 1, 'ligados': 0, 'itens': []}))));
    await t.pumpAndSettle();
    expect(find.text('Suas pendências'), findsOneWidget);
    expect(find.text('Sem pendências'), findsOneWidget);
  });


  testWidgets('com tipo ligado e nada pendente mostra "Sem pendências"', (t) async {
    await t.pumpWidget(_app(BlocoPendencias(repositorio: _repo((_) => {'code': 1, 'ligados': 3, 'itens': []}))));
    await t.pumpAndSettle();
    expect(find.text('Suas pendências'), findsOneWidget);
    expect(find.text('Sem pendências'), findsOneWidget);
  });

  testWidgets('itens mostram o selo em texto, não só a cor', (t) async {
    await t.pumpWidget(_app(BlocoPendencias(repositorio: _repo((_) => _lista))));
    await t.pumpAndSettle();
    expect(find.text('Obrigatória'), findsOneWidget);
    expect(find.text('Lembrete'), findsOneWidget);
    expect(find.textContaining('PD-SIGRH-FALHA'), findsOneWidget);
  });
}
