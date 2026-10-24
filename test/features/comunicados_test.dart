import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:projetonovo/core/config/app_config.dart';
import 'package:projetonovo/core/erros/falha_app.dart';
import 'package:projetonovo/core/rede/api_client.dart';
import 'package:projetonovo/features/comunicados/comunicados_page.dart';
import 'package:projetonovo/features/comunicados/comunicados_repositorio.dart';
import 'package:projetonovo/models/auth_model.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object corpo) => http.Response(jsonEncode(corpo), 200,
    headers: {'content-type': 'application/json; charset=utf-8'});

const _lista = {
  'code': 1,
  'categorias': [
    {'chave': 'operacao', 'nome': 'Operação', 'cor': '#1D4ED8', 'icone': 'local_police'},
  ],
  'itens': [
    {
      'id': 1, 'titulo': 'Operação Eleições', 'resumo': 'Escala do 2º turno', 'texto': 'Texto.',
      'categoria': 'operacao', 'origem': 'Comando-Geral', 'urgente': true, 'ciencia': true,
      'versao': 2, 'lido': false, 'ciente': false,
      'pilula': {'icone': 'calendar_month', 'texto': 'Até 30/10'},
    },
    {
      'id': 2, 'titulo': 'Outubro Rosa', 'texto': 'x', 'categoria': 'desconhecida', 'origem': 'Saúde',
      'lido': true,
    },
  ],
};

ComunicadosRepositorio _repo(Object Function(Map<String, String>) responder, {List<Map<String, String>>? pedidos}) =>
    ComunicadosRepositorio(
      api: ApiClient(
          cliente: MockClient((r) async {
            pedidos?.add(r.bodyFields);
            return _json(responder(r.bodyFields));
          }),
          temInternet: () async => true),
      matricula: '1234567',
      senhaMd5: 'a' * 32,
      url: Uri.parse('https://teste/comunicados.php'),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ComunicadosRepositorio.emUso.value = null;
  });

  test('listar lê categoria, pílula e ciência; categoria desconhecida cai na reserva', () async {
    final l = await _repo((_) => _lista).listar();
    expect(l, hasLength(2));
    expect(l.first.categoria.nome, 'Operação');
    expect(l.first.pilula?.texto, 'Até 30/10');
    expect(l.first.cienciaPendente, isTrue);
    expect(l.last.categoria.chave, CategoriaComunicado.reserva.chave);
    expect(ComunicadosRepositorio.emUso.value, same(l));
  });

  test('ciência manda o id e o aparelho e atualiza a lista em uso', () async {
    final pedidos = <Map<String, String>>[];
    final repo = _repo((c) => c['acao'] == 'listar' ? _lista : {'code': 1}, pedidos: pedidos);
    final l = await repo.listar();
    await repo.darCiencia(l.first);
    expect(pedidos.last['acao'], 'ciente');
    expect(pedidos.last['id'], '1');
    expect(pedidos.last['aparelho_id'], isNotEmpty);
    expect(ComunicadosRepositorio.emUso.value!.first.ciente, isTrue);
  });

  test('recusa da API vira FalhaApp CM-', () async {
    await expectLater(
      _repo((_) => {'code': 0, 'erro': 'NAO_ENCONTRADO', 'message': 'Não está mais no ar.'}).listar(),
      throwsA(isA<FalhaApp>().having((f) => f.codigo, 'codigo', 'CM-NAO-ENCONTRADO')),
    );
  });

  test('imagem de fundo do painel: só https vira foto; outro endereço é ignorado', () {
    Comunicado com(Object? imagem) => Comunicado.deJson(
        {'id': 1, 'titulo': 't', 'texto': 'x', 'categoria': 'operacao', 'origem': 'o', 'imagem': imagem}, const {});
    expect(com('https://pmrr.online/painelsoupmrr/midia/abc.jpg').imagem,
        'https://pmrr.online/painelsoupmrr/midia/abc.jpg');
    expect(com('http://exemplo.com/a.jpg').imagem, isNull);
    expect(com(null).imagem, isNull);
    expect(com('https://pmrr.online/x.jpg').copiar(lido: true).imagem, 'https://pmrr.online/x.jpg');
  });

  test('app_config: fonte dos comunicados é firestore até o painel trocar', () {
    expect(AppConfig.deJson({}, origem: OrigemConfig.rede).fonteComunicados, 'firestore');
    expect(
        AppConfig.deJson({'comunicados': {'fonte': 'api'}}, origem: OrigemConfig.rede).fonteComunicados, 'api');
  });

  testWidgets('central filtra ciência pendente e mostra o vazio', (t) async {
    final repo = _repo((_) => _lista);
    await t.pumpWidget(ChangeNotifierProvider<Auth>.value(
        value: Auth(), child: MaterialApp(home: CentralComunicadosPage(repositorio: repo))));
    await t.pumpAndSettle();
    expect(find.text('Operação Eleições'), findsOneWidget);
    expect(find.text('Outubro Rosa'), findsOneWidget);
    await t.tap(find.text('Ciência pendente').first);
    await t.pumpAndSettle();
    expect(find.text('Outubro Rosa'), findsNothing);
    await t.tap(find.text('Não lidos'));
    await t.pumpAndSettle();
    expect(find.text('Operação Eleições'), findsOneWidget);
  });

  testWidgets('carrossel some sem comunicado no ar', (t) async {
    final repo = _repo((_) => {'code': 1, 'categorias': [], 'itens': []});
    await t.pumpWidget(MaterialApp(home: Scaffold(body: BlocoComunicados(repositorio: repo))));
    await t.pumpAndSettle();
    expect(find.text('Comunicados'), findsNothing);
  });
}
