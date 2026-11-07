import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:projetonovo/core/erros/falha_app.dart';
import 'package:projetonovo/core/rede/api_client.dart';
import 'package:projetonovo/core/sessao/sessao.dart';
import 'package:projetonovo/features/operacoes/meu_servico.dart';
import 'package:projetonovo/features/operacoes/operar_api.dart';

/// Cofre de mentira: o de verdade é o Keychain/Keystore, que não existe no teste.
class _CofreMemoria implements Cofre {
  final Map<String, String> dados = {};

  @override
  Future<String?> ler(String chave) async => dados[chave];

  @override
  Future<void> gravar(String chave, String valor) async => dados[chave] = valor;

  @override
  Future<void> apagar(String chave) async {
    dados.remove(chave);
  }
}

/// Resposta como o servidor manda de verdade: JSON em UTF-8, com o
/// content-type dito. As duas coisas importam. Sem `charset=utf-8` o
/// `http.Response` grava o corpo em latin-1 e "Operações" chega quebrado; e
/// sem "json" no content-type o `ApiClient` recusa qualquer status fora do 200
/// antes de devolvê-lo — o que esconderia o caminho do 401.
http.Response _json(String corpo, [int status = 200]) => http.Response(
      corpo,
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

ApiClient _clienteQueResponde(http.Response Function(http.BaseRequest) f) =>
    ApiClient(
      cliente: MockClient((pedido) async => f(pedido)),
      temInternet: () async => true,
    );

String _ok({String token = 'tok-1', String matricula = '0041096009'}) =>
    jsonEncode({
      'code': 1,
      'token': token,
      'matricula': matricula,
      'nome': 'LUCAS SILVA',
      'posto': 'CB',
      'cpf_gravado': false,
    });

void main() {
  group('token do aparelho', () {
    // A regra mais cara do módulo: o /api/acesso do Operar REVOGA os outros
    // aparelhos da matrícula. Se o app pedisse um token a cada abertura, quem
    // usa o app do Operar pelo navegador seria derrubado toda vez.
    test('token guardado é reusado: abrir de novo não pede outro ao servidor',
        () async {
      var pedidos = 0;
      final cofre = _CofreMemoria()
        ..dados['operar_token'] = 'tok-guardado'
        ..dados['operar_matricula'] = '0041096009';
      final sessao = SessaoOperar(
        cofre: cofre,
        api: OperarApi(
          api: _clienteQueResponde((_) {
            pedidos++;
            return _json(_ok(), 200);
          }),
          matricula: '0041096009',
          senhaMd5: 'md5',
        ),
      );

      expect(await sessao.token(), 'tok-guardado');
      expect(await sessao.token(), 'tok-guardado');
      expect(pedidos, 0, reason: 'nenhuma chamada: o token já estava no cofre');
    });

    test('token de outra matrícula não serve — o aparelho trocou de dono',
        () async {
      var pedidos = 0;
      final cofre = _CofreMemoria()
        ..dados['operar_token'] = 'tok-de-outro'
        ..dados['operar_matricula'] = '0099999009';
      final sessao = SessaoOperar(
        cofre: cofre,
        api: OperarApi(
          api: _clienteQueResponde((_) {
            pedidos++;
            return _json(_ok(token: 'tok-novo'), 200);
          }),
          matricula: '0041096009',
          senhaMd5: 'md5',
        ),
      );

      expect(await sessao.token(), 'tok-novo');
      expect(pedidos, 1);
      expect(cofre.dados['operar_matricula'], '0041096009');
    });

    test('renovar força um token novo mesmo com um guardado válido', () async {
      var pedidos = 0;
      final cofre = _CofreMemoria()
        ..dados['operar_token'] = 'tok-velho'
        ..dados['operar_matricula'] = '0041096009';
      final sessao = SessaoOperar(
        cofre: cofre,
        api: OperarApi(
          api: _clienteQueResponde((_) {
            pedidos++;
            return _json(_ok(token: 'tok-novo'), 200);
          }),
          matricula: '0041096009',
          senhaMd5: 'md5',
        ),
      );

      expect(await sessao.token(renovar: true), 'tok-novo');
      expect(pedidos, 1);
      expect(cofre.dados['operar_token'], 'tok-novo');
    });

    // O Operar conhece o militar por duas representações da mesma matrícula.
    // Se a etiqueta do cofre fosse a que o servidor devolve, ela nunca casaria
    // com a do Sou PM e o módulo pediria token novo a cada abertura — que é o
    // único jeito de quebrar a regra do /api/acesso sem querer.
    test('matrícula devolvida diferente não faz pedir token de novo', () async {
      var pedidos = 0;
      final cofre = _CofreMemoria();
      final cliente = _clienteQueResponde((_) {
        pedidos++;
        return _json(_ok(matricula: '0041096009'));
      });
      SessaoOperar nova() => SessaoOperar(
            cofre: cofre,
            api: OperarApi(api: cliente, matricula: '452955', senhaMd5: 'md5'),
          );

      expect(await nova().token(), 'tok-1');
      expect(await nova().token(), 'tok-1');
      expect(pedidos, 1);
    });

    test('sair do app leva o token do Operar junto', () async {
      final cofre = _CofreMemoria()
        ..dados['operar_token'] = 'tok'
        ..dados['operar_matricula'] = '0041096009';

      await SessaoOperar.limparDoAparelho(cofre: cofre);

      expect(cofre.dados['operar_token'], isNull);
      expect(cofre.dados['operar_matricula'], isNull);
    });

    // O token sai do cofre no logout, mas a escala, o PIN e as conversas do
    // Operar ficam no `localStorage` da WebView, que o cofre não alcança. A
    // marca é o que leva a tela a esvaziá-lo na próxima abertura — sem ela, a
    // limpeza dependeria só do melhor esforço nativo do logout.
    test('o logout deixa marca para esvaziar o armazém da WebView', () async {
      final cofre = _CofreMemoria();

      expect(await SessaoOperar.consumirMarcaDeLimpeza(cofre: cofre), isFalse);

      await SessaoOperar.limparDoAparelho(cofre: cofre);

      expect(await SessaoOperar.consumirMarcaDeLimpeza(cofre: cofre), isTrue);
      // Consumida uma vez: a abertura seguinte não esvazia de novo, senão o
      // militar perderia a escala guardada a cada entrada no módulo.
      expect(await SessaoOperar.consumirMarcaDeLimpeza(cofre: cofre), isFalse);
      expect(cofre.dados, isEmpty);
    });
  });

  group('recusa da API', () {
    test('code 0 vira FalhaApp com o prefixo OP-', () async {
      final api = OperarApi(
        api: _clienteQueResponde((_) => _json(
            jsonEncode({
              'code': 0,
              'erro': 'SENHA_OPERACAO_AUSENTE',
              'message': 'A senha da operação não está cadastrada.',
            }),
            200)),
        matricula: '0041096009',
        senhaMd5: 'md5',
      );

      await expectLater(
        api.pedirToken(),
        throwsA(isA<FalhaApp>()
            .having((f) => f.codigo, 'codigo', 'OP-SENHA-OPERACAO-AUSENTE')
            .having((f) => f.texto, 'texto',
                'A senha da operação não está cadastrada.')),
      );
    });

    test('resposta sem token é recusada em vez de virar token vazio', () async {
      final api = OperarApi(
        api: _clienteQueResponde(
            (_) => _json(jsonEncode({'code': 1, 'token': ''}), 200)),
        matricula: '0041096009',
        senhaMd5: 'md5',
      );

      await expectLater(api.pedirToken(), throwsA(isA<FalhaApp>()));
    });
  });

  group('meu serviço', () {
    SessaoOperar sessaoCom(ApiClient c, _CofreMemoria cofre) => SessaoOperar(
          cofre: cofre,
          api: OperarApi(api: c, matricula: '0041096009', senhaMd5: 'md5'),
        );

    test('lê o serviço do militar e o nome curto da operação', () async {
      final cofre = _CofreMemoria()
        ..dados['operar_token'] = 'tok'
        ..dados['operar_matricula'] = '0041096009';
      final cliente = _clienteQueResponde((_) => _json(
          jsonEncode({
            'militar': {'nome_guerra': 'SILVA'},
            'evento': {'curto': 'Expoferr', 'nome': 'Expoferr 2026'},
            'servicos': [
              {
                'data': '2026-11-03',
                'escala': 'Evento',
                'funcao': 'Cmte_Gu',
                'restrita': false,
                'posto': {
                  'descricao': 'Portão 2',
                  'hora_inicio': '18:00',
                  'hora_fim': '23:00',
                },
                'local': {'nome': 'Parque do Rio Branco', 'municipio': 'Boa Vista'},
              },
            ],
          }),
          200));

      final s = await MeuServicoApi(api: cliente, sessao: sessaoCom(cliente, cofre)).ler();

      expect(s.temServico, isTrue);
      expect(s.evento, 'Expoferr');
      expect(s.nomeGuerra, 'SILVA');
      expect(s.proximo!.local, 'Parque do Rio Branco');
      expect(s.proximo!.municipio, 'Boa Vista');
      expect(s.proximo!.horaInicio, '18:00');
      expect(s.proximo!.funcao, 'Cmte_Gu');
    });

    test('sem serviço o card não tem o que desenhar', () async {
      final cofre = _CofreMemoria()
        ..dados['operar_token'] = 'tok'
        ..dados['operar_matricula'] = '0041096009';
      final cliente = _clienteQueResponde((_) => _json(
          jsonEncode({'servicos': [], 'evento': null}), 200));

      final s = await MeuServicoApi(api: cliente, sessao: sessaoCom(cliente, cofre)).ler();

      expect(s.temServico, isFalse);
      expect(s.evento, isNull);
    });

    test('escala restrita vem sem detalhe e não quebra a leitura', () async {
      final cofre = _CofreMemoria()
        ..dados['operar_token'] = 'tok'
        ..dados['operar_matricula'] = '0041096009';
      final cliente = _clienteQueResponde((_) => _json(
          jsonEncode({
            'servicos': [
              {
                'data': '2026-11-03',
                'escala': 'Servico com a Assessoria Militar',
                'restrita': true,
              },
            ],
          }),
          200));

      final s = await MeuServicoApi(api: cliente, sessao: sessaoCom(cliente, cofre)).ler();

      expect(s.proximo!.restrita, isTrue);
      expect(s.proximo!.local, isNull);
      expect(s.proximo!.posto, isNull);
    });

    // 401 é o Operar dizendo que o aparelho foi desligado do outro lado. Vale
    // pedir um token novo UMA vez; insistir viraria laço.
    test('401 pede token novo e tenta de novo, uma vez só', () async {
      final cofre = _CofreMemoria()
        ..dados['operar_token'] = 'tok-velho'
        ..dados['operar_matricula'] = '0041096009';
      var servicos = 0;
      var tokens = 0;
      final cliente = _clienteQueResponde((pedido) {
        if (pedido.url.path.endsWith('operar_token.php')) {
          tokens++;
          return _json(_ok(token: 'tok-novo'), 200);
        }
        servicos++;
        return servicos == 1
            ? _json('{"detail":"nao autorizado"}', 401)
            : _json(jsonEncode({'servicos': []}), 200);
      });

      final s = await MeuServicoApi(api: cliente, sessao: sessaoCom(cliente, cofre)).ler();

      expect(s.temServico, isFalse);
      expect(tokens, 1, reason: 'um token novo, não um por tentativa');
      expect(servicos, 2, reason: 'a primeira com o token velho, a segunda com o novo');
      expect(cofre.dados['operar_token'], 'tok-novo');
    });

    test('erro que não é 401 sobe como falha, sem pedir token novo', () async {
      final cofre = _CofreMemoria()
        ..dados['operar_token'] = 'tok'
        ..dados['operar_matricula'] = '0041096009';
      var tokens = 0;
      final cliente = _clienteQueResponde((pedido) {
        if (pedido.url.path.endsWith('operar_token.php')) {
          tokens++;
          return _json(_ok(), 200);
        }
        return _json('{"detail":"erro interno"}', 500);
      });

      await expectLater(
        MeuServicoApi(api: cliente, sessao: sessaoCom(cliente, cofre)).ler(),
        throwsA(isA<FalhaApp>()),
      );
      expect(tokens, 0);
    });
  });

  // Expoferr (1T) e ENEM (2T) abertos ao mesmo tempo: sem X-Turno o Operar
  // responde só da primeira, e o card do ENEM não existia (07/11/2026).
  group('uma operação por card', () {
    SessaoOperar sessaoCom(ApiClient c, _CofreMemoria cofre) => SessaoOperar(
          cofre: cofre,
          api: OperarApi(api: c, matricula: '0041096009', senhaMd5: 'md5'),
        );
    _CofreMemoria cofreComToken() => _CofreMemoria()
      ..dados['operar_token'] = 'tok'
      ..dados['operar_matricula'] = '0041096009';

    test('lista só as operações abertas, com o código do turno', () async {
      final cliente = _clienteQueResponde((_) => _json(
          jsonEncode({
            'evento': {'modo_evento': true, 'nome': 'Expoferr 2026'},
            'meus': ['1T', '2T'],
            'eventos': [
              {'codigo': '1T', 'nome': 'Expoferr 2026', 'curto': 'Expoferr',
               'inicio': '2026-11-03', 'fim': '2026-11-08', 'acesso': {'modo': 'atual'}},
              {'codigo': '2T', 'nome': 'Operação ENEM 2026', 'curto': 'ENEM',
               'inicio': '2026-11-08', 'fim': '2026-11-15', 'acesso': {'modo': 'atual'}},
              {'codigo': '0T', 'nome': 'Eleições 2026', 'acesso': {'modo': 'consulta'}},
            ],
          }),
          200));

      final l = await MeuServicoApi(api: cliente, sessao: sessaoCom(cliente, cofreComToken())).eventos();

      expect(l.map((e) => e.codigo), ['1T', '2T'], reason: 'a eleição encerrada não vira card');
      expect(l[0].titulo, 'Operação Expoferr 2026');
      expect(l[1].titulo, 'Operação ENEM 2026', reason: 'sem repetir "Operação"');
    });

    test('fora do modo evento a lista vem vazia: um card só, como antes', () async {
      final cliente = _clienteQueResponde((_) => _json(
          jsonEncode({'evento': {'modo_evento': false}, 'eventos': []}), 200));

      final l = await MeuServicoApi(api: cliente, sessao: sessaoCom(cliente, cofreComToken())).eventos();

      expect(l, isEmpty);
    });

    test('a leitura de uma operação leva X-Turno e o nome vem dela', () async {
      String? turno;
      final cliente = _clienteQueResponde((pedido) {
        turno = pedido.headers['X-Turno'];
        return _json(
            jsonEncode({
              // o bloco "evento" da resposta é o da instância, não o escolhido
              'evento': {'curto': 'Expoferr', 'inicio': '2026-11-03', 'fim': '2026-11-08'},
              'servicos': [
                {'data': '2026-11-08', 'escala': 'ENEM', 'publicada': false},
              ],
            }),
            200);
      });
      const enem = EventoOperar(
          codigo: '2T', nome: 'Operação ENEM 2026', curto: 'ENEM',
          inicio: '2026-11-08', fim: '2026-11-15');

      final s = await MeuServicoApi(api: cliente, sessao: sessaoCom(cliente, cofreComToken()))
          .ler(evento: enem);

      expect(turno, '2T');
      expect(s.evento, 'ENEM');
      expect(s.periodoEvento, '08/11 a 15/11');
      expect(s.proximo!.emPlanejamento, isTrue);
    });

    test('sem operação, o pedido não leva X-Turno', () async {
      var temTurno = true;
      final cliente = _clienteQueResponde((pedido) {
        temTurno = pedido.headers.containsKey('X-Turno');
        return _json(jsonEncode({'servicos': []}), 200);
      });

      await MeuServicoApi(api: cliente, sessao: sessaoCom(cliente, cofreComToken())).ler();

      expect(temTurno, isFalse);
    });
  });
}
