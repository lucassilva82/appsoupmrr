import 'package:flutter_test/flutter_test.dart';
import 'package:projetonovo/core/navegacao/menu_padrao.dart';
import 'package:projetonovo/features/inicio/linha_atalhos.dart';

void main() {
  test('sem atalho cortado: o que não cabe vira "Mais"', () {
    expect(atalhosQueCabem(378, 7), 4, reason: '5 lugares: 4 atalhos + Mais');
    expect(atalhosQueCabem(378, 5), 5);
    expect(atalhosQueCabem(900, 7), 7, reason: 'iPad: cabem todos');
  });

  test('atalho de função que o militar não vê some sozinho', () {
    final menu = menuPadrao(gestor: false);
    final r = resolverAtalhos(menu, atalhosPadrao(gestor: true));
    expect(r.map((a) => a.item.chave), isNot(contains('gestao.mapa_forca')));
    expect(r.length, 6);
  });

  test('aceita a chave antiga como apelido', () {
    final r = resolverAtalhos(menuPadrao(gestor: false), ['contracheques']);
    expect(r.single.item.chave, 'rh.contracheques');
    expect(r.single.area.chave, 'rh');
  });
}
