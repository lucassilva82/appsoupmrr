import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:projetonovo/core/erros/falha_app.dart';
import 'package:projetonovo/core/rede/api_client.dart';
import 'package:projetonovo/features/chamados/chamados_api.dart';
import 'package:projetonovo/features/chamados/chamados_page.dart';
import 'package:projetonovo/models/auth_model.dart';
import 'package:provider/provider.dart';

class _CofreMemoria implements CofreToken {
  final m = <String, String>{};
  @override
  Future<String?> ler(String matricula) async => m[matricula];
  @override
  Future<void> gravar(String matricula, String token) async => m[matricula] = token;
  @override
  Future<void> apagar(String matricula) async => m.remove(matricula);
}

http.Response _r(Object corpo, [int status = 200]) =>
    http.Response(jsonEncode(corpo), status, headers: {'content-type': 'application/json; charset=utf-8'});

/// Servidor falso do SISCHAMADOS, no formato do API_MOBILE.md.
class _Servidor {
  _Servidor({this.senhaCerta = 'app123'});
  final String senhaCerta;
  final pedidos = <http.BaseRequest>[];
  String tokenValido = 'tk1';
  int sessoes = 0;

  Future<http.Response> responder(http.Request r) async {
    pedidos.add(r);
    if (r.headers['X-App-Chave'] != 'chave-teste') {
      return _r({'ok': false, 'erro': {'codigo': 'APP_DESCONHECIDO', 'mensagem': 'Aplicativo não reconhecido.'}}, 401);
    }
    final rota = r.url.path.split('/v1/').last;
    if (rota == 'sessao' && r.method == 'POST') {
      final b = jsonDecode(r.body) as Map;
      if (b['senha'] != senhaCerta) {
        return _r({'ok': false, 'erro': {'codigo': 'CREDENCIAL_INVALIDA', 'mensagem': 'Matrícula ou senha incorreta.'}}, 401);
      }
      sessoes++;
      return _r({'ok': true, 'dados': {'token': tokenValido, 'expira_em': '2026-11-30 10:00:00'}}, 201);
    }
    if (r.headers['Authorization'] != 'Bearer $tokenValido') {
      return _r({'ok': false, 'erro': {'codigo': 'SESSAO_EXPIRADA', 'mensagem': 'Sua sessão expirou.'}}, 401);
    }
    if (rota == 'catalogo') {
      return _r({'ok': true, 'dados': {'grupos': [
        {'id': 1, 'nome': 'Suporte SEI', 'assuntos': [
          {'id': 2, 'nome': 'Senha do SEI', 'requer_anexo': false,
           'campos': [{'chave': 'sistema', 'rotulo': 'Sistema', 'tipo': 'select', 'obrigatorio': true, 'opcoes': ['SEI', 'SIGEPM']}],
           'prioridade': 'Alta', 'prazo_resposta_horas': 8},
        ]},
      ]}});
    }
    if (rota.startsWith('chamados') && r.method == 'GET' && !rota.contains('/')) {
      return _r({'ok': true, 'dados': {'chamados': [
        {'id': 452, 'protocolo': 'TI-2026-000012', 'titulo': 'Não consigo acessar o SEI', 'assunto': 'Senha do SEI',
         'situacao': 'Aberto', 'prioridade': 'Alta', 'aberto_em': '2026-10-06 11:15:16', 'atualizado_em': '2026-10-06 11:15:16'},
        {'id': 400, 'protocolo': 'TI-2026-000001', 'titulo': 'Impressora', 'assunto': 'Impressão',
         'situacao': 'Encerrado', 'aberto_em': '2026-09-01 08:00:00'},
      ], 'pagina': 1, 'paginas': 1, 'total': 2}});
    }
    if (rota == 'chamados' && r.method == 'POST') {
      final b = jsonDecode(r.body) as Map;
      if ((b['descricao'] as String).length < 15) {
        return _r({'ok': false, 'erro': {'codigo': 'DADOS_INVALIDOS', 'mensagem': 'Faltam informações no chamado.',
          'detalhes': {'descricao': 'Detalhe em pelo menos 15 caracteres.'}}}, 422);
      }
      return _r({'ok': true, 'dados': {'id': 453, 'protocolo': 'TI-2026-000013', 'situacao': 'Aberto'}}, 201);
    }
    return _r({'ok': false, 'erro': {'codigo': 'NAO_ENCONTRADO', 'mensagem': 'Rota não encontrada.'}}, 404);
  }
}

ChamadosApi _api(_Servidor s, {String senhaApp = 'app123', String? intranet, _CofreMemoria? cofre, String chave = 'chave-teste'}) =>
    ChamadosApi(
      api: ApiClient(cliente: MockClient(s.responder), temInternet: () async => true),
      matricula: '1234567',
      senhaApp: senhaApp,
      cofre: cofre ?? _CofreMemoria(),
      senhaIntranetGuardada: () async => intranet,
      base: 'https://teste/sischamados/api/v1',
      chave: chave,
    );

void main() {
  test('entra com a senha do app, guarda o token e manda a chave e o Bearer', () async {
    final s = _Servidor();
    final cofre = _CofreMemoria();
    final lista = await _api(s, cofre: cofre).meus();
    expect(lista, hasLength(2));
    expect(lista.first.encerrado, isFalse);
    expect(lista.last.encerrado, isTrue);
    expect(cofre.m['1234567'], 'tk1');
    expect(s.pedidos.last.headers['Authorization'], 'Bearer tk1');
  });

  test('token vencido: entra de novo uma vez, sozinho', () async {
    final s = _Servidor();
    final cofre = _CofreMemoria()..m['1234567'] = 'velho';
    await _api(s, cofre: cofre).catalogo();
    expect(s.sessoes, 1);
    expect(cofre.m['1234567'], 'tk1');
  });

  test('senha do app recusada e sem senha da intranet guardada: CH-SENHA', () async {
    await expectLater(_api(_Servidor(senhaCerta: 'outra'), senhaApp: 'app123').meus(),
        throwsA(isA<FalhaApp>().having((f) => f.codigo, 'codigo', 'CH-SENHA')));
  });

  test('tenta a senha da intranet guardada antes da do app', () async {
    final s = _Servidor(senhaCerta: 'intranet9');
    await _api(s, senhaApp: 'app123', intranet: 'intranet9').meus();
    final login = s.pedidos.firstWhere((p) => p.url.path.endsWith('/sessao')) as http.Request;
    expect(jsonDecode(login.body)['senha'], 'intranet9');
  });

  test('build sem a chave do app não chama a rede: CH-CHAVE', () async {
    final s = _Servidor();
    await expectLater(_api(s, chave: '').meus(), throwsA(isA<FalhaApp>().having((f) => f.codigo, 'codigo', 'CH-CHAVE')));
    expect(s.pedidos, isEmpty);
  });

  test('abrir com dados inválidos devolve o recado de cada campo', () async {
    await expectLater(
      _api(_Servidor()).abrir(assuntoId: 2, titulo: 'SEI fora', descricao: 'curta', campos: {'sistema': 'SEI'}),
      throwsA(isA<FalhaCampos>()
          .having((f) => f.codigo, 'codigo', 'CH-DADOS-INVALIDOS')
          .having((f) => f.detalhes['descricao'], 'detalhe', contains('15'))),
    );
    final ok = await _api(_Servidor())
        .abrir(assuntoId: 2, titulo: 'SEI fora', descricao: 'Desde ontem a senha não entra.', campos: {'sistema': 'SEI'});
    expect(ok.protocolo, 'TI-2026-000013');
  });

  testWidgets('Meus chamados separa em aberto e encerrados', (t) async {
    await t.pumpWidget(ChangeNotifierProvider<Auth>.value(
        value: Auth(), child: MaterialApp(home: MeusChamadosPage(api: _api(_Servidor())))));
    await t.pumpAndSettle();
    expect(find.text('Não consigo acessar o SEI'), findsOneWidget);
    expect(find.text('Impressora'), findsNothing);
    await t.tap(find.textContaining('Encerrados'));
    await t.pumpAndSettle();
    expect(find.text('Impressora'), findsOneWidget);
  });
}
