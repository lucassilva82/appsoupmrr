import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:projetonovo/core/sessao/sessao.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../apoio/cofre_memoria.dart';

void main() {
  late CofreMemoria cofre;
  late Sessao sessao;

  setUp(() {
    cofre = CofreMemoria();
    sessao = Sessao(cofre: cofre);
  });

  Future<Map<String, dynamic>> userData() async {
    final p = await SharedPreferences.getInstance();
    return jsonDecode(p.getString('userData') ?? '{}') as Map<String, dynamic>;
  }

  test(
      'quem já estava logado na versão antiga continua logado e a senha '
      'sai do armazenamento comum', () async {
    SharedPreferences.setMockInitialValues({
      'userData': jsonEncode({
        'matricula': '1234567',
        'password': 'senha-antiga',
        'autorizado': 'true',
      }),
    });

    final migrou = await sessao.migrar();

    expect(migrou, isTrue);
    expect(await sessao.senha(), 'senha-antiga');
    final dados = await userData();
    expect(dados.containsKey('password'), isFalse);
    expect(dados['matricula'], '1234567');
    expect(dados['autorizado'], 'true');
  });

  test('a senha do "lembrar meus dados" também vai para o cofre', () async {
    SharedPreferences.setMockInitialValues({
      'matricula': '1234567',
      'password': 'lembrada',
    });

    await sessao.migrar();

    expect(await sessao.senhaLembrada(), 'lembrada');
    final p = await SharedPreferences.getInstance();
    expect(p.getString('password'), isNull);
    expect(p.getString('matricula'), '1234567');
  });

  test('migrar de novo não muda nada nem apaga a senha do cofre', () async {
    SharedPreferences.setMockInitialValues({
      'userData': jsonEncode({'matricula': '1', 'password': 'x'}),
    });
    await sessao.migrar();

    final migrouDeNovo = await sessao.migrar();

    expect(migrouDeNovo, isFalse);
    expect(await sessao.senha(), 'x');
  });

  test('sem nada guardado, não há senha nem migração', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await sessao.migrar(), isFalse);
    expect(await sessao.senha(), isNull);
  });

  test('apagar tira as duas senhas do cofre', () async {
    await sessao.gravarSenha('a');
    await sessao.gravarSenhaLembrada('b');
    await sessao.apagarTudo();
    expect(await sessao.senha(), isNull);
    expect(await sessao.senhaLembrada(), isNull);
  });
}
