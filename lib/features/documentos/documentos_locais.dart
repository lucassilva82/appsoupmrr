import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Um contracheque em PDF guardado no aparelho (§12.3: "o último PDF baixado
/// fica guardado no aparelho, como as certidões"). O caminho é montado na
/// leitura, porque a pasta do app muda de nome no iPhone a cada atualização.
class ContrachequeGuardado {
  const ContrachequeGuardado({
    required this.id,
    required this.titulo,
    required this.ano,
    required this.mes,
    required this.guardadoEm,
    required this.caminho,
  });

  final String id;
  final String titulo;
  final int ano;
  final int mes;
  final DateTime guardadoEm;
  final String caminho;

  Map<String, Object?> toJson() =>
      {'id': id, 'titulo': titulo, 'ano': ano, 'mes': mes, 'guardado_em': guardadoEm.toIso8601String()};

  static ContrachequeGuardado? deJson(Object? j, String pasta) {
    if (j is! Map || j['id'] is! String || !RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(j['id'] as String)) return null;
    final em = DateTime.tryParse('${j['guardado_em']}');
    if (em == null) return null;
    return ContrachequeGuardado(
      id: j['id'] as String,
      titulo: '${j['titulo'] ?? 'Contracheque'}',
      ano: (j['ano'] as num?)?.toInt() ?? 0,
      mes: (j['mes'] as num?)?.toInt() ?? 0,
      guardadoEm: em,
      caminho: '$pasta/${j['id']}.pdf',
    );
  }
}

/// Guarda os PDFs de contracheque por matrícula, até [limite] (os mais antigos
/// saem). Leitura e gravação passam por uma fila, uma de cada vez (a lição do
/// APRENDIZADOS §26: limpeza que confia numa leitura cruzada apaga o que não
/// devia).
class DocumentosLocais {
  DocumentosLocais({Future<Directory> Function()? raiz}) : _raiz = raiz ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _raiz;
  static const limite = 24;
  static Future<void> _fila = Future.value();

  Future<T> _emFila<T>(Future<T> Function() op) {
    final r = _fila.then((_) => op());
    _fila = r.then((_) {}, onError: (_) {});
    return r;
  }

  Future<Directory> _pasta(String matricula) async {
    final seguro = matricula.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final d = Directory('${(await _raiz()).path}/documentos/contracheques/$seguro');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<List<ContrachequeGuardado>> _ler(Directory pasta) async {
    final indice = File('${pasta.path}/indice.json');
    if (!await indice.exists()) return [];
    final j = jsonDecode(await indice.readAsString());
    return [
      for (final e in (j is List ? j : const []))
        if (ContrachequeGuardado.deJson(e, pasta.path) case final c?) c,
    ];
  }

  Future<List<ContrachequeGuardado>> contracheques(String matricula) => _emFila(() async {
        try {
          final lista = await _ler(await _pasta(matricula));
          final existem = [for (final c in lista) if (await File(c.caminho).exists()) c];
          return existem..sort((a, b) => (b.ano * 100 + b.mes).compareTo(a.ano * 100 + a.mes));
        } catch (e) {
          debugPrint('[DOCS] ler: $e');
          return [];
        }
      });

  /// Copia o PDF para a pasta de documentos e registra. Falha aqui nunca
  /// atrapalha quem pediu o PDF: só não fica guardado.
  Future<void> guardarContracheque(String matricula, File pdf,
          {required String id, required String titulo, required int ano, required int mes}) =>
      _emFila(() async {
        try {
          final pasta = await _pasta(matricula);
          final lido = await _ler(pasta);
          await pdf.copy('${pasta.path}/$id.pdf');
          final lista = [
            ContrachequeGuardado(
                id: id, titulo: titulo, ano: ano, mes: mes, guardadoEm: DateTime.now(), caminho: '${pasta.path}/$id.pdf'),
            for (final c in lido) if (c.id != id) c,
          ]..sort((a, b) => (b.ano * 100 + b.mes).compareTo(a.ano * 100 + a.mes));
          final fica = lista.take(limite).toList();
          await File('${pasta.path}/indice.json').writeAsString(jsonEncode([for (final c in fica) c.toJson()]));
          // Só apaga o que saiu do índice que acabou de ser gravado.
          for (final c in lista.skip(limite)) {
            final f = File(c.caminho);
            if (await f.exists()) await f.delete();
          }
        } catch (e) {
          debugPrint('[DOCS] guardar: $e');
        }
      });

  Future<void> remover(String matricula, String id) => _emFila(() async {
        final pasta = await _pasta(matricula);
        final lista = (await _ler(pasta)).where((c) => c.id != id).toList();
        await File('${pasta.path}/indice.json').writeAsString(jsonEncode([for (final c in lista) c.toJson()]));
        final f = File('${pasta.path}/$id.pdf');
        if (await f.exists()) await f.delete();
      });
}
