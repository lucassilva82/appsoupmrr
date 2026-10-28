import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:projetonovo/core/erros/falha_app.dart';
import 'package:projetonovo/core/rede/api_client.dart';
import 'package:projetonovo/features/ajuda/ajuda_modelo.dart';
import 'package:projetonovo/features/feedback/feedback_repositorio.dart';

http.Response _json(Object corpo) => http.Response(jsonEncode(corpo), 200,
    headers: {'content-type': 'application/json; charset=utf-8'});

FeedbackRepositorio _repo(Object resposta, {void Function(http.Request)? viu}) => FeedbackRepositorio(
      api: ApiClient(
          cliente: MockClient((r) async {
            viu?.call(r);
            return _json(resposta);
          }),
          temInternet: () async => true),
      matricula: '1234567',
      senhaMd5: 'a' * 32,
      url: Uri.parse('https://teste/feedback.php'),
    );

void main() {
  test('enviar manda matrícula, tipo e texto e devolve o protocolo', () async {
    late http.Request pedido;
    final p = await _repo({'code': 1, 'id': 9, 'protocolo': 'FB-2026-00009'}, viu: (r) => pedido = r)
        .enviar(tipo: TipoFeedback.funcaoNova, texto: 'Quero escalas no calendário');
    expect(p, 'FB-2026-00009');
    final corpo = utf8.decode(pedido.bodyBytes);
    expect(corpo, contains('funcao_nova'));
    expect(corpo, contains('1234567'));
    expect(pedido.url.query, isEmpty, reason: 'dado do militar nunca na URL');
  });

  test('recusa da API vira FalhaApp com o código FB- e o texto do servidor', () async {
    await expectLater(
      _repo({'code': 0, 'erro': 'ANEXO_GRANDE', 'message': 'Passou de 25 MB.'}).listar(),
      throwsA(isA<FalhaApp>()
          .having((f) => f.codigo, 'codigo', 'FB-ANEXO-GRANDE')
          .having((f) => f.texto, 'texto', 'Passou de 25 MB.')
          .having((f) => f.origem, 'origem', OrigemFalha.aparelho)),
    );
    await expectLater(
      _repo({'code': 0, 'erro': 'SESSAO_INVALIDA', 'message': 'Saia e entre.'}).listar(),
      throwsA(isA<FalhaApp>().having((f) => f.acao, 'acao', AcaoFalha.entrarDeNovo)),
    );
  });

  test('ver lê a conversa e marca o que é da equipe', () async {
    final d = await _repo({
      'code': 1,
      'feedback': {'id': 1, 'protocolo': 'FB-2026-00001', 'tipo': 'elogio', 'texto': 'Ótimo',
                   'situacao': 'concluido', 'aguarda_militar': false, 'anexos': 2},
      'mensagens': [
        {'autor': 'equipe', 'texto': 'Obrigado!'},
        {'autor': 'equipe', 'texto': 'Isso é técnico.', 'acao': 'abrir_chamado'},
        {'autor': 'militar', 'texto': 'ok', 'acao': 'abrir_chamado'},
      ],
    }).ver(1);
    expect(d.encerrado, isTrue);
    expect(d.anexos, 2);
    expect(d.mensagens.first.daEquipe, isTrue);
    expect(d.mensagens.map((m) => m.abrirChamado), [false, true, false],
        reason: 'só mensagem da equipe oferece o chamado');
    expect(d.resumo.tipo, TipoFeedback.elogio);
  });

  test('ajuda: lê assuntos e ignora o que vem sem campo essencial', () {
    final l = AjudaAssunto.lista({
      'assuntos': [
        {'chave': 'acesso', 'nome': 'Conta', 'perguntas': [
          {'id': 1, 'pergunta': 'P?', 'resposta': 'R.', 'destino': 'rh.ficha'},
          {'pergunta': 'sem id'},
        ]},
        {'nome': 'sem chave'},
      ],
    })!;
    expect(l.single.perguntas.single.destino, 'rh.ficha');
    expect(AjudaAssunto.lista(null), isNull);
    expect(ajudaPadrao, isNotEmpty);
  });
}
