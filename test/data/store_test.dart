import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:projetonovo/core/log/registro_log.dart';
import 'package:projetonovo/data/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ArmazemMemoria implements ArmazemLog {
  List<Map<String, Object?>> fila = [];
  @override
  Future<List<Map<String, Object?>>> ler() async => List.of(fila);
  @override
  Future<void> gravar(List<Map<String, Object?>> itens) async =>
      fila = List.of(itens);
}

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

  group('lerMapa separa "não existe" de "não consegui ler"', () {
    late _ArmazemMemoria armazem;

    setUp(() {
      armazem = _ArmazemMemoria();
      RegistroLog.atual = RegistroLog(
        armazem: armazem,
        enviar: (_) async {},
        matricula: () => '1234567',
      );
    });

    tearDown(() => RegistroLog.atual = null);

    test('chave ausente é {} (vazio de verdade), não null', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await Store.lerMapa(chave), isEmpty);
      expect(armazem.fila, isEmpty, reason: 'ausente não é falha');
    });

    test('valor legível volta como mapa', () async {
      SharedPreferences.setMockInitialValues({chave: jsonEncode(dados)});
      expect(await Store.lerMapa(chave), dados);
      expect(armazem.fila, isEmpty);
    });

    test('valor corrompido é null, não {}', () async {
      SharedPreferences.setMockInitialValues({chave: 'isto não é json'});
      expect(await Store.lerMapa(chave), isNull);
    });

    test('JSON válido que não é objeto também é null', () async {
      SharedPreferences.setMockInitialValues({chave: '[1,2,3]'});
      expect(await Store.lerMapa(chave), isNull);
    });

    test('a falha vai para o log como ST-LEITURA, e sem o valor', () async {
      // O `utils/store.dart` foi apagado por imprimir o valor no log. O
      // registro daqui leva a chave e o tamanho, nunca o conteúdo.
      const segredo = '{"cpf":"12345678909","nome":"STIVES"';  // JSON truncado
      SharedPreferences.setMockInitialValues({chave: segredo});

      expect(await Store.lerMapa(chave), isNull);

      expect(armazem.fila, hasLength(1));
      final registro = armazem.fila.single;
      expect(registro['codigo'], 'ST-LEITURA');
      expect(registro['mostrado'], false, reason: 'falha de leitura é de log');
      expect(registro['mensagem'], contains(chave));
      expect(registro['mensagem'], contains('bytes=${segredo.length}'));
      expect(registro.toString(), isNot(contains('12345678909')));
      expect(registro.toString(), isNot(contains('STIVES')));
    });

    test('getMap continua tolerante: {} nos dois casos', () async {
      // Os 11 chamadores do getMap não mudam de comportamento.
      SharedPreferences.setMockInitialValues({chave: 'quebrado'});
      expect(await Store.getMap(chave), isEmpty);
      SharedPreferences.setMockInitialValues({});
      expect(await Store.getMap(chave), isEmpty);
    });

    test('ler-modificar-gravar: getMap apaga a sessão, lerMapa não', () async {
      // O defeito, em quatro linhas. É esta a forma dos quatro sítios que
      // regravavam a sessão em main.dart e auth_model.dart.
      const sessao = {'matricula': '1234567', 'nome': 'STIVES DA SILVA'};

      // Com getMap: a leitura falha, vem {}, e a gravação apaga tudo para
      // guardar uma escolha de notificação.
      SharedPreferences.setMockInitialValues({'userData': 'corrompido'});
      final comGetMap = await Store.getMap('userData');
      comGetMap['notificationsChoice'] = 'authorized';
      await Store.saveMap('userData', comGetMap);
      expect(await Store.getMap('userData'),
          {'notificationsChoice': 'authorized'},
          reason: 'matrícula e nome foram embora');

      // Com lerMapa: null, então não se grava nada por cima.
      SharedPreferences.setMockInitialValues({'userData': jsonEncode(sessao)});
      final intacto = await Store.lerMapa('userData');
      expect(intacto, sessao);

      SharedPreferences.setMockInitialValues({'userData': 'corrompido'});
      final comLerMapa = await Store.lerMapa('userData');
      expect(comLerMapa, isNull);
      // O guarda dos quatro sítios: `if (userData != null)`.
      if (comLerMapa != null) {
        comLerMapa['notificationsChoice'] = 'authorized';
        await Store.saveMap('userData', comLerMapa);
      }
      expect(await Store.getString('userData'), 'corrompido',
          reason: 'nada foi gravado por cima do que não se leu');
    });
  });
}
