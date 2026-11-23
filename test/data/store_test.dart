import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:projetonovo/data/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// O `utils/store.dart` foi apagado em 23/11/2026 e o seu único cliente, o
/// Cálculo de Inatividade, passou a usar este `Store`. Os dois tinham a mesma
/// classe `Store` com APIs incompatíveis, e o antigo imprimia no log o que
/// guardava — que ali é data de nascimento, data de incorporação, sexo e posto.
///
/// Estes testes provam o que a troca precisa garantir: que o cálculo que o
/// militar já tinha salvo no aparelho continua sendo lido, e que os casos que
/// o `Store` antigo tratava continuam tratados.
void main() {
  const chave = 'calculo_inatividade_dados_v1';

  // O mesmo mapa que `_salvar()` grava na tela de Cálculo de Inatividade.
  final dados = <String, dynamic>{
    'dataIncorporacao': '2010-03-01T00:00:00.000',
    'dataNascimento': '1988-07-14T00:00:00.000',
    'sexo': 'masculino',
    'posto': 'cabo',
    'diasServicoMilitarAnterior': 0,
    'diasAverbadosCivis': 1245,
    'diasFuncaoCivil': 0,
    'incapacidade': null,
    'calculado': true,
    'diasAfastamentos': 30,
  };

  test('chave ausente devolve mapa vazio, não exceção', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await Store.getMap(chave), isEmpty);
  });

  test('o que o Store antigo gravou continua sendo lido igual', () async {
    // Grava o valor cru, exatamente como o `utils/Store.saveMap` gravava
    // (jsonEncode do mapa, na mesma chave): é o que está hoje no aparelho de
    // quem já usou a tela. A troca não pode perder esse cálculo.
    SharedPreferences.setMockInitialValues({chave: jsonEncode(dados)});
    expect(await Store.getMap(chave), dados);
  });

  test('ida e volta preserva os campos', () async {
    SharedPreferences.setMockInitialValues({});
    await Store.saveMap(chave, dados);
    expect(await Store.getMap(chave), dados);
  });

  test('"Novo cálculo" grava mapa vazio e a leitura devolve vazio', () async {
    SharedPreferences.setMockInitialValues({chave: jsonEncode(dados)});
    await Store.saveMap(chave, {});
    expect(await Store.getMap(chave), isEmpty);
  });

  test('valor corrompido devolve vazio em vez de derrubar a tela', () async {
    // O Store antigo lançava aqui (`json.decode` sem try), e o erro subia de
    // um `await` do carregamento — ou seja, virava AP-FATAL. Como isto é só o
    // rascunho do formulário, voltar aos valores do SIGRH é o certo.
    SharedPreferences.setMockInitialValues({chave: 'isto não é json'});
    expect(await Store.getMap(chave), isEmpty);

    // JSON válido que não é um objeto: o antigo quebrava no `as Map`.
    SharedPreferences.setMockInitialValues({chave: '[1,2,3]'});
    expect(await Store.getMap(chave), isEmpty);
  });
}
