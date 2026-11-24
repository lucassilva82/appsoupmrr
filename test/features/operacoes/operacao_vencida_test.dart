import 'package:flutter_test/flutter_test.dart';
import 'package:projetonovo/features/operacoes/card_operacoes.dart';
import 'package:projetonovo/features/operacoes/meu_servico.dart';

/// O caso real de 24/11/2026: o Operar continuava anunciando a Operação ENEM
/// 2026, com `fim` em 15/11, e o card da Início mostrava a operação encerrada
/// no lugar do card geral de Operações.
void main() {
  EventoOperar evento({String? fim}) =>
      EventoOperar(codigo: '2T', nome: 'ENEM 2026', curto: 'ENEM', inicio: '2026-11-08', fim: fim);

  final hoje = DateTime(2026, 11, 24);

  test('a operação que terminou há nove dias está vencida', () {
    expect(operacaoVencida(evento(fim: '2026-11-15'), hoje: hoje), isTrue);
  });

  test('a operação que termina hoje ainda vale: o dia do fim conta inteiro', () {
    expect(operacaoVencida(evento(fim: '2026-11-24'), hoje: hoje), isFalse);
  });

  test('a operação que termina amanhã vale', () {
    expect(operacaoVencida(evento(fim: '2026-11-25'), hoje: hoje), isFalse);
  });

  test('a operação que terminou ontem está vencida', () {
    expect(operacaoVencida(evento(fim: '2026-11-23'), hoje: hoje), isTrue);
  });

  // As três abaixo são a regra do §27/§37: não sei a data não pode virar
  // "a operação acabou". Na dúvida, o card fica.
  test('sem data de fim, o evento fica', () {
    expect(operacaoVencida(evento(fim: null), hoje: hoje), isFalse);
  });

  test('com data vazia, o evento fica', () {
    expect(operacaoVencida(evento(fim: '   '), hoje: hoje), isFalse);
  });

  test('com data que não dá para ler, o evento fica', () {
    expect(operacaoVencida(evento(fim: '15/11/2026'), hoje: hoje), isFalse);
  });

  test('a hora do dia não muda a resposta', () {
    final cedo = DateTime(2026, 11, 24, 0, 1);
    final tarde = DateTime(2026, 11, 24, 23, 59);
    expect(operacaoVencida(evento(fim: '2026-11-24'), hoje: cedo), isFalse);
    expect(operacaoVencida(evento(fim: '2026-11-24'), hoje: tarde), isFalse);
  });
}
