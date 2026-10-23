import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:projetonovo/core/config/app_config.dart';
import 'package:projetonovo/core/rede/api_client.dart';

class _ArmazemMemoria implements ArmazemConfig {
  ({String json, String? etag, DateTime? em, String quem})? guardado;

  @override
  Future<({String json, String? etag, DateTime? em, String quem})?>
      ler() async => guardado;

  @override
  Future<void> gravar(
          String json, String? etag, DateTime em, String quem) async =>
      guardado = (json: json, etag: etag, em: em, quem: quem);
}

const _resposta = {
  'code': 1,
  'versao_config': 7,
  'sessao': 'ok',
  'versao': {
    'android': {'minima': '2.2.0', 'recomendada': '2.2.1'},
    'ios': {'minima': '2.1.5', 'recomendada': '2.1.5'},
  },
  'rede': {'timeout_s': 20},
  'campo_novo_do_painel': {'x': 1},
  'menu': [
    {
      'chave': 'rh',
      'tipo': 'area',
      'rotulo': 'Minha vida funcional',
      'visivel': true,
      'estado': 'ativo',
      'filhos': [
        {
          'chave': 'rh.contracheques',
          'tipo': 'funcao',
          'rotulo': 'Contracheques',
          'rota': '/contracheque-page',
          'apelidos': ['contracheques'],
          'visivel': true,
          'estado': 'bloqueado',
          'selo': 'Manutenção',
          'mensagem': {
            'motivo': 'manutencao',
            'titulo': 'Contracheque em manutenção',
            'texto': 'Volte às 18h.',
            'codigo': 'MD-RH.CONTRACHEQUES-MANUT',
          },
        },
        {'tipo': 'funcao', 'rotulo': 'sem chave: ignorado'},
      ],
    },
  ],
};

// O http.Response codifica em latin1 sem charset; a API manda UTF-8.
http.Response _json(Object corpo, {Map<String, String> headers = const {}}) =>
    http.Response(jsonEncode(corpo), 200, headers: {
      'content-type': 'application/json; charset=utf-8',
      ...headers,
    });

void main() {
  testesFase2();
  late _ArmazemMemoria armazem;
  late List<http.Request> pedidos;

  RepositorioConfig repo(Future<http.Response> Function(http.Request) h) =>
      RepositorioConfig(
        api: ApiClient(
            cliente: MockClient((r) {
              pedidos.add(r);
              return h(r);
            }),
            temInternet: () async => true),
        url: Uri.parse('https://teste/app_config.php'),
        plataforma: 'android',
        versaoApp: '2.2.0',
        armazem: armazem,
      );

  setUp(() {
    armazem = _ArmazemMemoria();
    pedidos = [];
  });

  test('lê da rede, guarda com o ETag e ignora o que não conhece', () async {
    final c = await repo((_) async => _json(_resposta, headers: {'etag': '"abc"'}))
        .carregar(matricula: '1234567', senhaMd5: 'a' * 32);
    expect(c.origem, OrigemConfig.rede);
    expect(c.versaoConfig, 7);
    expect(c.tempoLimiteRede, const Duration(seconds: 20));
    expect(c.menu.single.filhos.length, 1, reason: 'nó sem chave é ignorado');
    expect(armazem.guardado?.etag, '"abc"');
    expect(armazem.guardado?.quem, '1234567');
    final corpo = jsonDecode(pedidos.single.body) as Map;
    expect(corpo['plataforma'], 'android');
    expect(corpo['matricula'], '1234567');
  });

  test('304 usa a cópia guardada e manda o ETag', () async {
    await repo((_) async => _json(_resposta, headers: {'etag': '"abc"'}))
        .carregar(matricula: '1234567', senhaMd5: 'a' * 32);
    final c = await repo((_) async => http.Response('', 304))
        .carregar(matricula: '1234567', senhaMd5: 'a' * 32);
    expect(pedidos.last.headers['If-None-Match'], '"abc"');
    expect(c.versaoConfig, 7);
    expect(c.origem, OrigemConfig.cache);
  });

  test('servidor fora: usa a cópia; sem cópia, os padrões do código', () async {
    final semNada =
        await repo((_) async => http.Response('erro', 500)).carregar();
    expect(semNada.origem, OrigemConfig.padrao);
    expect(semNada.menu, isEmpty);

    await repo((_) async => _json(_resposta))
        .carregar();
    final c = await repo((_) async => http.Response('erro', 503)).carregar();
    expect(c.origem, OrigemConfig.cache);
    expect(c.versaoConfig, 7);
  });

  test('falha marca "sem conexão"; 304 e rede desmarcam (§5.3)', () async {
    await repo((_) async => http.Response('erro', 503)).carregar();
    expect(RepositorioConfig.semConexao.value, isTrue);
    await repo((_) async => _json(_resposta, headers: {'etag': '"abc"'})).carregar();
    expect(RepositorioConfig.semConexao.value, isFalse);
    await repo((_) async => http.Response('erro', 503)).carregar();
    await repo((_) async => http.Response('', 304)).carregar();
    expect(RepositorioConfig.semConexao.value, isFalse);
  });

  test('a cópia de um militar não vale para outro no mesmo aparelho', () async {
    await repo((_) async => _json(_resposta))
        .carregar(matricula: '1111111', senhaMd5: 'a' * 32);
    final c = await repo((_) async => http.Response('erro', 503))
        .carregar(matricula: '2222222', senhaMd5: 'b' * 32);
    expect(c.origem, OrigemConfig.padrao);
    expect(pedidos.last.headers.containsKey('If-None-Match'), isFalse);
  });

  test('acha a função pelo apelido antigo e lê a mensagem do bloqueio', () {
    final c = AppConfig.deJson(_resposta, origem: OrigemConfig.rede);
    final i = c.item('contracheques');
    expect(i?.chave, 'rh.contracheques');
    expect(i?.bloqueado, isTrue);
    expect(i?.mensagem?.codigo, 'MD-RH.CONTRACHEQUES-MANUT');
  });

  test(
      'versão: obrigatória abaixo da mínima, recomendada abaixo da recomendada',
      () {
    final c = AppConfig.deJson(_resposta, origem: OrigemConfig.rede);
    expect(c.situacaoVersao('android', '2.1.9'), SituacaoVersao.obrigatoria);
    expect(c.situacaoVersao('android', '2.2.0'), SituacaoVersao.recomendada);
    expect(c.situacaoVersao('android', '2.10.0'), SituacaoVersao.emDia);
    expect(c.situacaoVersao('ios', '2.1.5'), SituacaoVersao.emDia);
    expect(c.situacaoVersao('windows', '1.0.0'), SituacaoVersao.emDia);
  });
}

void testesFase2() {
  test('home e mais usados: lê a ordem do painel e ignora bloco sem chave', () {
    final c = AppConfig.deJson({
      'code': 1,
      'home': [
        {'chave': 'home.atalhos', 'ordem': 50, 'escondivel': true, 'dados': ['rh.ferias']},
        {'chave': 'home.comandantes', 'ordem': 10, 'escondivel': false, 'arte': 'estrelas'},
        {'ordem': 5},
      ],
      'servicos': {'mais_usados': ['rh.certidoes']},
    }, origem: OrigemConfig.rede);
    expect(c.home!.map((b) => b.chave), ['home.atalhos', 'home.comandantes']);
    expect(c.bloco('home.atalhos')!.dados, ['rh.ferias']);
    expect(c.bloco('home.comandantes')!.escondivel, isFalse);
    expect(c.blocoLigado('home.dicas'), isFalse, reason: 'desligado no painel');
    expect(c.maisUsados, ['rh.certidoes']);
  });

  test('API sem a fase 2: todo bloco vale e não há mais usados', () {
    final c = AppConfig.deJson({'code': 1}, origem: OrigemConfig.rede);
    expect(c.home, isNull);
    expect(c.blocoLigado('home.dicas'), isTrue);
    expect(c.maisUsados, isNull);
  });
}
