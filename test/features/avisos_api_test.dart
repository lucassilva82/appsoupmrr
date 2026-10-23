import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:projetonovo/core/erros/falha_app.dart';
import 'package:projetonovo/core/rede/api_client.dart';
import 'package:projetonovo/features/avisos/avisos_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

ApiClient _cliente(Object resposta, List<http.Request> pedidos) => ApiClient(
    cliente: MockClient((r) async {
      pedidos.add(r);
      return http.Response(jsonEncode(resposta), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    }),
    temInternet: () async => true);

void main() {
  late List<http.Request> pedidos;
  setUp(() {
    pedidos = [];
    SharedPreferences.setMockInitialValues({'soupm_aparelho_id': 'aparelho-teste-01'});
  });

  test('listar: mais antigas primeiro, com geral, lida e os campos do SIGE', () async {
    final api = AvisosApi(
      api: _cliente({
        'code': 1,
        'itens': [
          {'id': 9, 'titulo': 'Nova', 'mensagem': 'm', 'rota': '', 'criado_em': '2026-10-22T10:00:00-04', 'lida': false, 'geral': true},
          {'id': 3, 'titulo': 'Escala', 'mensagem': 'm', 'rota': '/escalas', 'criado_em': '2026-10-20T10:00:00-04',
           'lida': true, 'geral': false, 'tipo_evento': 'escalado', 'dados': {'referencia_id': 346, 'notificacao_id': 12}},
        ],
      }, pedidos),
      matricula: '1234567', senhaMd5: 'a' * 32, url: Uri.parse('https://teste/notificacoes.php'));
    final l = await api.listar();
    expect(l.map((n) => n.id), ['3', '9']);
    expect(l.first.clicked, isTrue);
    expect(l.first.referenciaId, '346');
    expect(l.first.notificacaoId, '12');
    expect(l.last.isGlobal, isTrue);
    expect(l.last.route, isNull, reason: 'rota vazia vira nula');
    expect(pedidos.single.bodyFields['acao'], 'listar');
  });

  test('recusa vira AV- com o texto do servidor', () async {
    final api = AvisosApi(
        api: _cliente({'code': 0, 'erro': 'SESSAO_INVALIDA', 'message': 'Saia e entre.'}, pedidos),
        matricula: '1', senhaMd5: 'a' * 32, url: Uri.parse('https://teste/n.php'));
    await expectLater(api.marcarLida('3'),
        throwsA(isA<FalhaApp>().having((f) => f.codigo, 'codigo', 'AV-SESSAO-INVALIDA')));
  });

  test('aparelho: registra com o id da instalação e remove sem senha', () async {
    final d = DispositivoApi(api: _cliente({'code': 1}, pedidos), url: Uri.parse('https://teste/dispositivo.php'));
    await d.registrar(token: 'tok_${'x' * 30}', matricula: '1234567', senhaMd5: 'a' * 32);
    await d.remover('tok_${'x' * 30}');
    expect(pedidos.first.bodyFields['aparelho_id'], 'aparelho-teste-01');
    expect(pedidos.first.bodyFields['acao'], 'registrar');
    expect(pedidos.last.bodyFields['acao'], 'remover');
    expect(pedidos.last.bodyFields.containsKey('senha'), isFalse);
  });
}
