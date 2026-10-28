import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projetonovo/core/design/fundo_circuito.dart';

/// AP-FATAL de 25/10/2026 (painel): a contagem de telas de entrada abertas
/// avisava os diálogos no meio do build. Entrar e sair da tela de entrada,
/// com alguém ouvindo a contagem, não pode gerar erro de build.
void main() {
  testWidgets('abrir e fechar a tela de entrada com um diálogo ouvindo a contagem', (t) async {
    final mostrar = ValueNotifier(true);
    await t.pumpWidget(MaterialApp(
      home: Stack(children: [
        Positioned.fill(
          child: ValueListenableBuilder<bool>(
            valueListenable: mostrar,
            builder: (_, m, __) => m ? const FundoCircuito() : const SizedBox(),
          ),
        ),
        Positioned(
          top: 0,
          child: ValueListenableBuilder<int>(
            valueListenable: FundoCircuito.abertos,
            builder: (_, n, __) => Text('abertos $n'),
          ),
        ),
      ]),
    ));
    await t.pump();
    expect(find.text('abertos 1'), findsOneWidget);
    mostrar.value = false;
    await t.pump();
    await t.pump();
    expect(t.takeException(), isNull);
    expect(find.text('abertos 0'), findsOneWidget);
  });
}
