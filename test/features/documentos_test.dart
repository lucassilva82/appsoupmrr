import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:projetonovo/features/documentos/documentos_locais.dart';
import 'package:projetonovo/features/documentos/documentos_page.dart';

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
}
