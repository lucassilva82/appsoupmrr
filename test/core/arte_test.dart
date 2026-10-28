import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projetonovo/core/config/app_config.dart';
import 'package:projetonovo/core/design/arte_cartao.dart';

void main() {
  tearDown(() => Arte.doPainel = const {});

  test('arte do painel vale por cima do catálogo; ícone desconhecido usa o do catálogo', () {
    AppConfig.deJson({
      'code': 1,
      'artes': [
        {'chave': 'cc', 'cores': ['#111111', '#222222', '#333333'], 'icones': ['payments', 'nao_existe', 'savings']},
        {'chave': 'ruim', 'cores': ['#12', '#222222', '#333333']},
        {'chave': 'nova', 'cores': ['#000000', '#101010', '#FFFFFF'], 'icones': ['celebration']},
      ],
    }, origem: OrigemConfig.rede);
    final cc = Arte.de('cc');
    expect(cc.base, const Color(0xFF111111));
    expect(cc.icones[1], Arte.catalogo['cc']!.icones[1]);
    expect(Arte.doPainel.containsKey('ruim'), isFalse, reason: 'cor inválida descarta');
    expect(Arte.de('nova').icones.first, Icons.celebration_outlined);
    expect(Arte.de('nao_cadastrada'), Arte.catalogo['rh']);
  });
}
