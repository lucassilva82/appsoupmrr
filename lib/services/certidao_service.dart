import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../data/store.dart';
import '../utils/api_services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CertidaoService
//
// Certidões de autoemissão: o PDF vem pronto da API (sigrh/certidoes/
// autoemissao.php), com QR Code de verificação, e fica guardado no aparelho
// enquanto vale — 30 dias. Vencida, sai da lista e o arquivo é apagado.
//
// Os arquivos ficam no diretório de suporte do app (não aparece em Arquivos
// nem em backup visível) porque a Ficha Funcional traz conta bancária,
// endereço e dependentes. No logout tudo é apagado (Auth.logout).
// ─────────────────────────────────────────────────────────────────────────────

/// Tipo que o militar pode emitir, como a API devolve no painel.
class TipoCertidao {
  final String tipo;
  final String titulo;
  final bool disponivel;
  final String? motivo;

  const TipoCertidao({
    required this.tipo,
    required this.titulo,
    required this.disponivel,
    this.motivo,
  });

  factory TipoCertidao.fromJson(Map<String, dynamic> j) => TipoCertidao(
        tipo: j['tipo'].toString(),
        titulo: j['titulo'].toString(),
        disponivel: j['disponivel'] == true,
        motivo: j['motivo']?.toString(),
      );
}

/// Painel: tipos, declaração vigente e validade.
class PainelCertidoes {
  final List<TipoCertidao> tipos;
  final int declaracaoVersao;
  final String declaracaoTexto;
  final int validadeDias;

  const PainelCertidoes({
    required this.tipos,
    required this.declaracaoVersao,
    required this.declaracaoTexto,
    required this.validadeDias,
  });
}

/// Certidão emitida e guardada no aparelho.
class CertidaoGuardada {
  final String tipo;
  final String titulo;
  final String codigo;
  final DateTime geradoEm;
  final DateTime validoAte;
  final String urlVerificacao;
  final String nomeArquivo;
  final String caminho;

  const CertidaoGuardada({
    required this.tipo,
    required this.titulo,
    required this.codigo,
    required this.geradoEm,
    required this.validoAte,
    required this.urlVerificacao,
    required this.nomeArquivo,
    required this.caminho,
  });

  bool get valida => DateTime.now().isBefore(validoAte);

  /// Dias inteiros que faltam (0 no último dia).
  int get diasRestantes => validoAte.difference(DateTime.now()).inDays;

  Map<String, dynamic> toJson() => {
        'tipo': tipo,
        'titulo': titulo,
        'codigo': codigo,
        'gerado_em': geradoEm.toIso8601String(),
        'valido_ate': validoAte.toIso8601String(),
        'url_verificacao': urlVerificacao,
        'nome_arquivo': nomeArquivo,
        'caminho': caminho,
      };

  factory CertidaoGuardada.fromJson(Map<String, dynamic> j) => CertidaoGuardada(
        tipo: j['tipo'].toString(),
        titulo: j['titulo'].toString(),
        codigo: j['codigo'].toString(),
        geradoEm: DateTime.parse(j['gerado_em'].toString()),
        validoAte: DateTime.parse(j['valido_ate'].toString()),
        urlVerificacao: j['url_verificacao'].toString(),
        nomeArquivo: j['nome_arquivo'].toString(),
        caminho: j['caminho'].toString(),
      );
}

/// Cópia por e-mail feita pela API logo depois da emissão.
class EnvioEmailCertidao {
  final bool enviado;

  /// E-mail com o meio oculto ("l***s@gmail.com"); nulo se não há confirmado.
  final String? emailMascarado;

  /// Explicação quando não foi enviado.
  final String? aviso;

  const EnvioEmailCertidao({required this.enviado, this.emailMascarado, this.aviso});

  factory EnvioEmailCertidao.fromJson(Map<String, dynamic>? j) => EnvioEmailCertidao(
        enviado: j?['enviado'] == true,
        emailMascarado: j?['email']?.toString(),
        aviso: j?['aviso']?.toString(),
      );
}

/// Resultado da emissão: a certidão guardada e o envio por e-mail.
class EmissaoCertidao {
  final CertidaoGuardada certidao;
  final EnvioEmailCertidao email;
  const EmissaoCertidao({required this.certidao, required this.email});
}

class CertidaoService {
  static String _chaveIndice(String matricula) => 'certidoes_$matricula';

  static Future<Directory> _pasta(String matricula) async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/certidoes/$matricula');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// A API manda "2026-10-16 10:38:22.07" no horário de Boa Vista (UTC-4).
  static DateTime _dataApi(String valor) {
    final iso = valor.trim().replaceFirst(' ', 'T');
    final semFracao = iso.contains('.') ? iso.substring(0, iso.indexOf('.')) : iso;
    return DateTime.parse('$semFracao-04:00').toLocal();
  }

  // ── Painel ────────────────────────────────────────────────────────────────

  static Future<PainelCertidoes> painel({
    required String matricula,
    required String senhaMd5,
  }) async {
    final r = await ApiServices.certidoes({
      'acao': 'painel',
      'matricula': matricula,
      'senha': senhaMd5,
    });
    if (r['code'] != 1) {
      throw CertidaoErro((r['message'] ?? 'Não foi possível carregar.').toString());
    }
    final declaracao = (r['declaracao'] as Map).cast<String, dynamic>();
    return PainelCertidoes(
      tipos: (r['tipos'] as List)
          .map((t) => TipoCertidao.fromJson((t as Map).cast<String, dynamic>()))
          .toList(),
      declaracaoVersao: (declaracao['versao'] as num).toInt(),
      declaracaoTexto: declaracao['texto'].toString(),
      validadeDias: (r['validade_dias'] as num?)?.toInt() ?? 30,
    );
  }

  // ── Emissão ───────────────────────────────────────────────────────────────

  /// Emite, grava o PDF e devolve a certidão já guardada, com o resultado
  /// do envio da cópia por e-mail.
  static Future<EmissaoCertidao> emitir({
    required String matricula,
    required String senhaMd5,
    required String tipo,
    required int declaracaoVersao,
  }) async {
    final r = await ApiServices.certidoes({
      'acao': 'emitir',
      'matricula': matricula,
      'senha': senhaMd5,
      'tipo': tipo,
      'declaracao_confirmada': '1',
      'declaracao_versao': '$declaracaoVersao',
    }, limite: const Duration(seconds: 60));

    if (r['code'] != 1) {
      throw CertidaoErro((r['message'] ?? 'Não foi possível emitir.').toString());
    }

    final bytes = base64Decode(r['pdf_base64'].toString());
    // Um PDF começa sempre por "%PDF": se não, a resposta veio quebrada.
    if (bytes.length < 5 || String.fromCharCodes(bytes.sublist(0, 4)) != '%PDF') {
      throw const CertidaoErro('O arquivo recebido está incompleto. Tente de novo.');
    }

    // A lista vem antes de gravar: guardadas() apaga PDF que não está nela.
    final lista = await guardadas(matricula);

    final codigo = r['codigo'].toString();
    final arquivo = File('${(await _pasta(matricula)).path}/$codigo.pdf');
    await arquivo.writeAsBytes(bytes, flush: true);

    final certidao = CertidaoGuardada(
      tipo: r['tipo'].toString(),
      titulo: r['titulo'].toString(),
      codigo: codigo,
      geradoEm: _dataApi(r['gerado_em'].toString()),
      validoAte: _dataApi(r['valido_ate'].toString()),
      urlVerificacao: r['url_verificacao'].toString(),
      nomeArquivo: r['nome_arquivo'].toString(),
      caminho: arquivo.path,
    );

    await _salvarIndice(matricula, [certidao, ...lista]);
    return EmissaoCertidao(
      certidao: certidao,
      email: EnvioEmailCertidao.fromJson((r['email'] as Map?)?.cast<String, dynamic>()),
    );
  }

  // ── Guardadas no aparelho ─────────────────────────────────────────────────

  /// Certidões ainda válidas, mais recentes primeiro. Remove as vencidas e
  /// as que perderam o arquivo.
  static Future<List<CertidaoGuardada>> guardadas(String matricula) async {
    final indice = await Store.getMap(_chaveIndice(matricula));
    final itens = (indice['itens'] as List?) ?? const [];

    final validas = <CertidaoGuardada>[];
    var mudou = false;
    for (final item in itens) {
      try {
        final c = CertidaoGuardada.fromJson((item as Map).cast<String, dynamic>());
        final arquivo = File(c.caminho);
        if (c.valida && await arquivo.exists()) {
          validas.add(c);
        } else {
          mudou = true;
          if (await arquivo.exists()) await arquivo.delete();
        }
      } catch (e) {
        debugPrint('[CERTIDAO] item inválido no índice: $e');
        mudou = true;
      }
    }

    // Só a mais recente de cada tipo fica no aparelho: emitir de novo
    // substitui a anterior na lista (que continua válida na verificação,
    // caso já tenha sido enviada a alguém).
    validas.sort((a, b) => b.geradoEm.compareTo(a.geradoEm));
    final tipos = <String>{};
    final ultimas = <CertidaoGuardada>[];
    for (final c in validas) {
      if (tipos.add(c.tipo)) {
        ultimas.add(c);
      } else {
        mudou = true;
        final arquivo = File(c.caminho);
        if (await arquivo.exists()) await arquivo.delete();
      }
    }

    if (mudou) await _salvarIndice(matricula, ultimas);

    // PDF que ficou na pasta sem estar na lista (de versões anteriores do
    // app, ou de uma gravação interrompida) também sai.
    try {
      final manter = ultimas.map((c) => c.caminho).toSet();
      final pasta = await _pasta(matricula);
      await for (final f in pasta.list()) {
        if (f is File && f.path.endsWith('.pdf') && !manter.contains(f.path)) {
          await f.delete();
        }
      }
    } catch (e) {
      debugPrint('[CERTIDAO] falha ao limpar a pasta: $e');
    }
    return ultimas;
  }

  static Future<void> _salvarIndice(String matricula, List<CertidaoGuardada> lista) =>
      Store.saveMap(_chaveIndice(matricula), {
        'itens': lista.map((c) => c.toJson()).toList(),
      });

  /// Apaga todas as certidões do aparelho (logout).
  static Future<void> apagarTudo() async {
    try {
      final base = await getApplicationSupportDirectory();
      final dir = Directory('${base.path}/certidoes');
      if (await dir.exists()) {
        for (final sub in dir.listSync().whereType<Directory>()) {
          await Store.remove(_chaveIndice(sub.uri.pathSegments.where((s) => s.isNotEmpty).last));
        }
        await dir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('[CERTIDAO] falha ao apagar certidões: $e');
    }
  }
}

/// Erro com mensagem pronta para o militar.
class CertidaoErro implements Exception {
  final String mensagem;
  const CertidaoErro(this.mensagem);

  @override
  String toString() => mensagem;
}
