import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projetonovo/core/design/entrada_inicio.dart';

/// Entrada suave da Início (26/10/2026): só depois do login, um bloco por vez,
/// e parada com "Reduzir movimento".
double _opacidade(WidgetTester t) {
  final o = find.byType(Opacity);
  return o.evaluate().isEmpty ? 1 : t.widget<Opacity>(o.first).opacity;
}

Widget _app({required bool ativa, bool semMovimento = false, int indice = 1}) => MediaQuery(
      data: MediaQueryData(disableAnimations: semMovimento),
      child: MaterialApp(home: SurgeEntrada(indice: indice, ativa: ativa, child: const Text('bloco'))),
    );

void main() {
  testWidgets('depois do login o bloco começa invisível e aparece em menos de 1 s', (t) async {
    await t.pumpWidget(_app(ativa: true, indice: 3));
    expect(_opacidade(t), 0);
    for (var ms = 0; ms < 900; ms += 16) {
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(_opacidade(t), 1);
  });

  testWidgets('fora da entrada (trocar de aba, abrir já logado) desenha direto', (t) async {
    await t.pumpWidget(_app(ativa: false));
    expect(find.byType(Opacity), findsNothing);
    expect(find.text('bloco'), findsOneWidget);
  });

  testWidgets('com Reduzir movimento nada se mexe', (t) async {
    await t.pumpWidget(_app(ativa: true, semMovimento: true));
    expect(find.byType(Opacity), findsNothing);
  });

  testWidgets('blocos muito abaixo (fora da tela) não entram em cascata', (t) async {
    await t.pumpWidget(_app(ativa: true, indice: EntradaInicio.maxEmCascata));
    expect(find.byType(Opacity), findsNothing);
  });

  testWidgets('com o convite do Face ID aberto, espera ele fechar para animar', (t) async {
    final convite = ValueNotifier<bool>(true);
    EntradaInicio.aguardar = convite;
    addTearDown(() => EntradaInicio.aguardar = null);
    await t.pumpWidget(_app(ativa: true));
    for (var ms = 0; ms < 900; ms += 16) {
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(_opacidade(t), 0, reason: 'animar por trás do convite seria animar para ninguém ver');
    convite.value = false;
    for (var ms = 0; ms < 900; ms += 16) {
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(_opacidade(t), 1);
  });
}
