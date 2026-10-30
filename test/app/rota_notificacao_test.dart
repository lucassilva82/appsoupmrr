import 'package:flutter_test/flutter_test.dart';
import 'package:projetonovo/main.dart' show rotaDaNotificacao;
import 'package:projetonovo/utils/app_routes.dart';

/// Teste de 25/10/2026: o "Abrir" do aviso e o push só aceitavam a lista
/// fixa da 2.1, e as rotas e chaves da 2.2 eram ignoradas.
void main() {
  test('rota antiga da lista continua valendo', () {
    expect(rotaDaNotificacao('/certidoes-page'), '/certidoes-page');
  });

  test('rota de módulo da 2.2 e chave da função abrem', () {
    expect(rotaDaNotificacao('/com/central'), AppRoutes.COMUNICADOS);
    expect(rotaDaNotificacao('rh.contracheques'), AppRoutes.CONTRACHEQUE_PAGE);
    expect(rotaDaNotificacao('/contracheques'), AppRoutes.CONTRACHEQUE_PAGE);
    expect(rotaDaNotificacao('atend.feedback'), AppRoutes.FEEDBACK);
  });

  test('desconhecida, vazia ou que pede argumentos não abre', () {
    expect(rotaDaNotificacao('/qualquer-coisa'), isNull);
    expect(rotaDaNotificacao('  '), isNull);
    expect(rotaDaNotificacao('rh.contracheques.grafico'), isNull);
  });

  // O push do Operar manda a tela dentro da rota, porque o contrato de push do
  // app só tem `route` — não há bloco de dados livre. Antes, rota com query
  // não casava com módulo nenhum e o toque não abria nada.
  test('rota com query resolve o módulo pelo caminho', () {
    expect(rotaDaNotificacao('/op/operacoes?abrir=escala'), AppRoutes.OPERACOES);
    expect(rotaDaNotificacao('/op/operacoes'), AppRoutes.OPERACOES);
    expect(rotaDaNotificacao('op.operacoes'), AppRoutes.OPERACOES);
  });

  test('query não faz rota desconhecida passar', () {
    expect(rotaDaNotificacao('/qualquer-coisa?abrir=x'), isNull);
  });
}
