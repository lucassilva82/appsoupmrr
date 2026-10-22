import 'package:flutter_test/flutter_test.dart';
import 'package:projetonovo/app/registro_modulos.dart';
import 'package:projetonovo/utils/app_routes.dart';

void main() {
  test('a chave antiga do plano acha o mesmo módulo da chave nova', () {
    expect(
        registroModulos.porChave('contracheques')?.chave, 'rh.contracheques');
    expect(registroModulos.porChave('rh.contracheques')?.rotuloPadrao,
        'Contracheques');
  });

  test('o plantão leva para Minhas escalas, pela chave e pela rota do push',
      () {
    expect(registroModulos.porChave('op.plantao')?.chave, 'op.escalas');
    expect(registroModulos.porRota(AppRoutes.PLANTAO)?.chave, 'op.escalas');
  });

  test('rota desconhecida não acha módulo (o app pede para atualizar)', () {
    expect(registroModulos.porRota('/rota-que-nao-existe'), isNull);
  });

  test('toda chave segue o formato e todo prefixo está na tabela do §9.1', () {
    final formato = RegExp(r'^[a-z_]+(\.[a-z_]+)*$');
    for (final m in registroModulos.todos) {
      expect(formato.hasMatch(m.chave), isTrue, reason: m.chave);
      expect(prefixosConhecidos, contains(m.prefixoErro), reason: m.chave);
    }
  });

  test('duas funções nunca têm a mesma rota', () {
    final rotas =
        registroModulos.todos.map((m) => m.rota).whereType<String>().toList();
    expect(rotas.toSet().length, rotas.length);
  });
}
