import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projetonovo/features/documentos/documentos_locais.dart';
import 'package:projetonovo/features/documentos/documentos_page.dart';
import 'package:projetonovo/models/auth_model.dart';
import 'package:provider/provider.dart';

void main() {
  test('busca sem acento, em qualquer palavra', () {
    final itens = [
      ItemDocumento(titulo: 'Certidão de Comportamento', detalhe: 'Certidão · válida', data: DateTime(2026), tipo: 'certidao'),
      ItemDocumento(titulo: 'Contracheque Março/2026', detalhe: 'Contracheque', data: DateTime(2026), tipo: 'contracheque'),
    ];
    expect(filtrarDocumentos(itens, 'certidao').length, 1);
    expect(filtrarDocumentos(itens, 'marco 2026').single.tipo, 'contracheque');
    expect(filtrarDocumentos(itens, '').length, 2);
  });

  test('guarda, ordena, limita e remove contracheques', () async {
    final raiz = await Directory.systemTemp.createTemp('docs');
    addTearDown(() => raiz.delete(recursive: true));
    final docs = DocumentosLocais(raiz: () async => raiz);
    final pdf = File('${raiz.path}/x.pdf')..writeAsStringSync('%PDF-1.4');
    for (var m = 1; m <= DocumentosLocais.limite + 2; m++) {
      await docs.guardarContracheque('123', pdf, id: 'cc_$m', titulo: 'M$m', ano: 2024 + (m - 1) ~/ 12, mes: (m - 1) % 12 + 1);
    }
    final lista = await docs.contracheques('123');
    expect(lista.length, DocumentosLocais.limite);
    expect(lista.first.id, 'cc_${DocumentosLocais.limite + 2}');
    expect(File('${raiz.path}/documentos/contracheques/123/cc_1.pdf').existsSync(), isFalse);
    await docs.remover('123', lista.first.id);
    expect((await docs.contracheques('123')).length, DocumentosLocais.limite - 1);
    expect(await docs.contracheques('outra'), isEmpty);
  });

  // Origem que não respondeu aparece dizendo isso, com o código, em vez de
  // simplesmente não aparecer (SOUPM_2_2 §4.3; APRENDIZADOS §27 e §37).
  final falha = ItemDocumento(
    titulo: 'Não foi possível conferir suas certidões',
    detalhe: 'Nada foi apagado · CT-INDICE',
    data: DateTime(2026, 11, 24),
    tipo: 'falha',
  );

  test('a linha de falha não é filtrada pela busca', () {
    final itens = [
      falha,
      ItemDocumento(titulo: 'Contracheque Março/2026', detalhe: 'Contracheque', data: DateTime(2026, 3), tipo: 'contracheque'),
    ];
    // Busca que não casa com o texto da falha: ela fica, senão a tela diria
    // "Nenhum documento com ..." com as certidões ilegíveis.
    final r = filtrarDocumentos(itens, 'marco');
    expect(r.map((i) => i.tipo), ['falha', 'contracheque']);
    expect(filtrarDocumentos(itens, 'nao existe nada assim').single.ehFalha, isTrue);
  });

  testWidgets('a linha de falha não abre nada: sem seta e sem toque', (t) async {
    await t.pumpWidget(ChangeNotifierProvider<Auth>.value(
      value: Auth(),
      child: MaterialApp(
        home: DocumentosPage(carregar: (_) async => [falha]),
      ),
    ));
    await t.pumpAndSettle();

    expect(find.text('Não foi possível conferir suas certidões'), findsOneWidget);
    expect(find.byIcon(Icons.folder_off_rounded), findsOneWidget);
    // Sem seta: prometer uma tela que não existe é pior que a falha.
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    expect(t.widget<ListTile>(find.byType(ListTile)).onTap, isNull);
  });
}
