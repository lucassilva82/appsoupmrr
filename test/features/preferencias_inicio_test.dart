import 'package:flutter_test/flutter_test.dart';
import 'package:projetonovo/core/config/app_config.dart';
import 'package:projetonovo/features/inicio/preferencias_inicio.dart';

BlocoInicio _b(String c, int ordem, {bool escondivel = true}) =>
    BlocoInicio(chave: 'home.$c', ordem: ordem, escondivel: escondivel);

PreferenciasInicio _p(List<(String, bool)> blocos) =>
    PreferenciasInicio(blocos: [for (final (c, v) in blocos) (chave: 'home.$c', visivel: v)]);

void main() {
  final painel = [
    _b('comandantes', 10, escondivel: false),
    _b('dicas', 30),
    _b('atalhos', 50),
    _b('contracheque', 60),
    _b('ferias', 80),
  ];

  test('sem escolha do militar vale a ordem do painel', () {
    expect(ordenarBlocos(painel, null),
        ['home.comandantes', 'home.dicas', 'home.atalhos', 'home.contracheque', 'home.ferias']);
  });

  test('a ordem é a do militar e o que ele escondeu some', () {
    final r = ordenarBlocos(painel, _p([
      ('ferias', true), ('comandantes', true), ('dicas', false), ('atalhos', true), ('contracheque', true),
    ]));
    expect(r, ['home.ferias', 'home.comandantes', 'home.atalhos', 'home.contracheque']);
  });

  test('bloco fixo nunca some, mesmo marcado como escondido', () {
    expect(ordenarBlocos(painel, _p([('comandantes', false), ('dicas', true)])), contains('home.comandantes'));
  });

  test('bloco novo do painel entra logo depois do vizinho de cima do painel', () {
    final comCard = [...painel, _b('livre.outubro_rosa', 55)];
    final r = ordenarBlocos(comCard, _p([
      ('ferias', true), ('comandantes', true), ('dicas', true), ('atalhos', true), ('contracheque', true),
    ]));
    expect(r.indexOf('home.livre.outubro_rosa'), r.indexOf('home.atalhos') + 1);
  });

  test('bloco desligado no painel não aparece; ao voltar, volta para onde o militar deixou', () {
    final pref = _p([('ferias', true), ('comandantes', true), ('dicas', true), ('atalhos', true), ('contracheque', true)]);
    final semFerias = painel.where((b) => b.chave != 'home.ferias').toList();
    expect(ordenarBlocos(semFerias, pref), isNot(contains('home.ferias')));
    expect(ordenarBlocos(painel, pref).first, 'home.ferias');
  });

  test('json de ida e volta', () {
    final p = PreferenciasInicio(blocos: [(chave: 'home.dicas', visivel: false)], atalhos: ['rh.ficha']);
    final de = PreferenciasInicio.deJson(p.paraJson())!;
    expect(de.blocos.single.visivel, isFalse);
    expect(de.atalhos, ['rh.ficha']);
    expect(PreferenciasInicio.deJson({'blocos': []})!.atalhos, isNull, reason: 'sem atalhos = o padrão do painel');
  });
}
