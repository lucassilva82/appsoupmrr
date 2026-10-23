import 'package:flutter_test/flutter_test.dart';
import 'package:projetonovo/core/config/app_config.dart';
import 'package:projetonovo/core/navegacao/menu_padrao.dart';
import 'package:projetonovo/features/servicos/servicos_page.dart';

void main() {
  test('menu de reserva: Gestão só para gestor, plantão fora do menu', () {
    final militar = menuEmUso(AppConfig.padrao, gestor: false);
    final gestor = menuEmUso(AppConfig.padrao, gestor: true);
    expect(militar.map((a) => a.chave), ['rh', 'operacional', 'normas', 'atendimento']);
    expect(gestor.map((a) => a.chave).last, 'gestao');
    final op = militar.firstWhere((a) => a.chave == 'operacional');
    expect(op.filhos.map((f) => f.chave), isNot(contains('op.plantao')));
  });

  test('área sem função visível some sozinha', () {
    final c = AppConfig.deJson({
      'code': 1,
      'menu': [
        {
          'chave': 'normas',
          'tipo': 'area',
          'rotulo': 'Normas',
          'filhos': [
            {'chave': 'normas.pops', 'tipo': 'funcao', 'rotulo': 'POPs', 'visivel': false},
          ],
        },
        {
          'chave': 'rh',
          'tipo': 'area',
          'rotulo': 'RH',
          'filhos': [
            {'chave': 'rh.ferias', 'tipo': 'funcao', 'rotulo': 'Férias'},
          ],
        },
      ],
    }, origem: OrigemConfig.rede);
    expect(menuEmUso(c, gestor: false).map((a) => a.chave), ['rh']);
  });

  test('busca sem acento, por sinônimo e por prefixo de palavra', () {
    final menu = menuPadrao(gestor: false);
    List<String> achou(String t) =>
        buscarFuncoes(menu, t).map((r) => r.item.chave).toList();
    expect(achou('holerite'), ['rh.contracheques']);
    expect(achou('ferias'), contains('rh.ferias'));
    expect(achou('APOSENT'), ['rh.tempo_servico']);
    expect(achou('xyz'), isEmpty);
    expect(achou('  '), isEmpty);
  });

  test('normalizar tira acento e caixa', () {
    expect(normalizar('Férias Ação ÇÃO'), 'ferias acao cao');
  });

  group('busca tolerante a erro de digitação', () {
    final menu = menuPadrao(gestor: false);
    test('acha com uma ou duas letras erradas', () {
      expect(buscarFuncoes(menu, 'contraxeque').map((r) => r.item.chave), contains('rh.contracheques'));
      expect(buscarFuncoes(menu, 'cerridoes').map((r) => r.item.chave), contains('rh.certidoes'));
    });
    test('resultado exato vem sem os aproximados', () {
      expect(buscarFuncoes(menu, 'ferias').map((r) => r.item.chave), contains('rh.ferias'));
      expect(buscarFuncoes(menu, 'xyzw'), isEmpty);
    });
    test('distância de edição', () {
      expect(distanciaEdicao('casa', 'caso'), 1);
      expect(distanciaEdicao('abc', 'abcdef', limite: 1), 2);
    });
  });
}
