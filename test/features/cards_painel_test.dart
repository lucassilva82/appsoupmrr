import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projetonovo/core/config/app_config.dart';
import 'package:projetonovo/features/inicio/card_painel.dart';
import 'package:projetonovo/features/inicio/faixa_comando.dart';
import 'package:projetonovo/models/auth_model.dart';
import 'package:provider/provider.dart';

BlocoInicio _bloco(Map<String, dynamic> j) => BlocoInicio.lista([j]).single;

void main() {
  test('bloco guarda o JSON bruto e separa itens de objeto das chaves de atalho', () {
    final atalhos = _bloco({'chave': 'home.atalhos', 'dados': ['rh.ficha', 'rh.ferias']});
    expect(atalhos.dados, ['rh.ficha', 'rh.ferias']);
    expect(atalhos.itens, isEmpty);

    final comando = _bloco({
      'chave': 'home.comandantes',
      'dados': [
        {'posto': 'CEL QOC PM', 'nome': 'FULANO FICTICIO', 'cargo': 'Comandante-Geral'}
      ]
    });
    expect(comando.dados, isEmpty, reason: 'objeto não vira atalho');
    expect(comando.itens.single['posto'], 'CEL QOC PM');
  });

  test('card do painel: modelo desconhecido, sem título ou número sem valor não desenha', () {
    expect(CardPainel.desenha(_bloco({'chave': 'home.livre.a', 'modelo': 'carrossel3d', 'dados': {'titulo': 'x'}})), isFalse);
    expect(CardPainel.desenha(_bloco({'chave': 'home.livre.b', 'modelo': 'campanha', 'dados': {'texto': 'x'}})), isFalse);
    expect(CardPainel.desenha(_bloco({'chave': 'home.livre.c', 'modelo': 'numero', 'dados': {'titulo': 'Escalas'}})), isFalse);
    expect(CardPainel.desenha(_bloco({'chave': 'home.livre.d', 'modelo': 'campanha', 'dados': {'titulo': 'Outubro Rosa'}})), isTrue);
    expect(_bloco({'chave': 'home.livre.d'}).livre, isTrue);
  });

  test('comandante do painel vira o cartão com posto, nome e os detalhes', () {
    final c = FaixaComando.doPainel({
      'posto': 'CEL QOC PM',
      'nome': 'FULANO DE TAL FICTICIO',
      'nome_guerra': 'FICTICIO',
      'cargo': 'Comandante-Geral',
      'foto': 'https://exemplo/foto.jpg',
      'quadro': 'QOC',
      'desde': '2025-01-02',
      'cursos': ['CSP', 'CAO'],
      'mensagem': 'Bom serviço.',
    });
    expect(c['title'], 'CEL QOC PM FICTICIO');
    expect(c['img'], 'https://exemplo/foto.jpg');
    expect(c['subtitle'], 'Bom serviço.');
    expect(c['posto'], 'CEL QOC PM');
    expect(c['nome_completo'], 'FULANO DE TAL FICTICIO');
    final detalhes = [for (final (_, r, v) in (c['detalhes'] as List).cast<(IconData, String, String)>()) (r, v)];
    expect(detalhes, contains(('No cargo desde', '02/01/2025')));
    expect(detalhes, contains(('Cursos', 'CSP · CAO')));
  });

  testWidgets('card de campanha mostra selo, título, texto e o rótulo da ação', (t) async {
    final b = _bloco({
      'chave': 'home.livre.outubro_rosa',
      'modelo': 'campanha',
      'arte': 'rosa',
      'dados': {'selo': 'Campanha', 'titulo': 'Outubro Rosa', 'texto': 'Exames preventivos.'},
      'acao': {'tipo': 'comunicado', 'rotulo': 'Saiba mais'},
    });
    await t.pumpWidget(ChangeNotifierProvider<Auth>.value(
        value: Auth(), child: MaterialApp(home: Scaffold(body: CardPainel(bloco: b)))));
    expect(find.text('Campanha'), findsOneWidget);
    expect(find.text('Outubro Rosa'), findsOneWidget);
    expect(find.text('Saiba mais'), findsOneWidget);
  });

  test('comunicado fixado como card: chega como campanha com o id do comunicado na ação', () {
    final b = _bloco({
      'chave': 'home.livre.comunicado_12',
      'modelo': 'campanha',
      'ordem': 50,
      'escondivel': true,
      'dados': {'selo': 'Saúde', 'titulo': 'Vacinação no QCG', 'texto': 'Gripe e hepatite B, das 8h às 16h.'},
      'acao': {'tipo': 'comunicado', 'destino': '12', 'rotulo': 'Saiba mais'},
      'arte': 'rosa',
      'arte_estilo': 'cheio',
    });
    expect(b.livre, isTrue);
    expect(b.ordem, 50);
    expect(CardPainel.desenha(b), isTrue);
    expect(int.tryParse('${(b.bruto['acao'] as Map)['destino']}'), 12);
  });
}
