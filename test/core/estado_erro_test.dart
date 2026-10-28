import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projetonovo/core/erros/estado_erro.dart';
import 'package:projetonovo/core/erros/falha_app.dart';

void main() {
  testWidgets('tela de erro: viatura, de quem é, tentar de novo, código e detalhes técnicos', (t) async {
    var tentou = false;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EstadoErro(
          falha: FalhaApp.lento('CC', detalhe: 'timeout'),
          aoTentar: () => tentou = true,
          tela: 'rh.contracheques',
        ),
      ),
    ));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byType(ViaturaQuebrada), findsOneWidget);
    expect(find.text('CC-LENTO'), findsOneWidget);
    expect(find.text('O que fazer'), findsOneWidget);
    expect(find.text('Abrir chamado técnico'), findsNothing, reason: 'sem a chave do SISCHAMADOS no build');
    await t.ensureVisible(find.text('Tentar de novo'));
    await t.tap(find.text('Tentar de novo'));
    expect(tentou, isTrue);
    await t.ensureVisible(find.text('Detalhes técnicos'));
    await t.pump();
    await t.tap(find.text('Detalhes técnicos'));
    await t.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 2))
        .catchError((_) => 0);
    expect(find.textContaining('Tela: rh.contracheques'), findsOneWidget);
    expect(find.textContaining('Código: CC-LENTO'), findsOneWidget);
  });
}
