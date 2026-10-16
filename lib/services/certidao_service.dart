import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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

  /// Quando foi emitida a certidão deste tipo que ainda vale. Emitir de novo
  /// revoga essa no servidor, e o app avisa antes.
  final DateTime? vigenteDesde;

  const TipoCertidao({
    required this.tipo,
    required this.titulo,
    required this.disponivel,
    this.motivo,
    this.vigenteDesde,
  });

  factory TipoCertidao.fromJson(Map<String, dynamic> j) => TipoCertidao(
        tipo: j['tipo'].toString(),
        titulo: j['titulo'].toString(),
        disponivel: j['disponivel'] == true,
        motivo: j['motivo']?.toString(),
        vigenteDesde: j['vigente_desde'] == null
            ? null
            : CertidaoService._dataApi(j['vigente_desde'].toString()),
      );
}

/// Painel: tipos, declaração vigente e validade.
class PainelCertidoes {
  final List<TipoCertidao> tipos;
  final int declaracaoVersao;
  final String declaracaoTexto;
  final int validadeDias;

  /// Certidões revogadas no servidor (código → motivo), para tirar do
  /// aparelho a que não vale mais.
  final Map<String, String?> revogadas;

  const PainelCertidoes({
    required this.tipos,
    required this.declaracaoVersao,
    required this.declaracaoTexto,
    required this.validadeDias,
    this.revogadas = const {},
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

  /// Caminho do PDF, montado a cada leitura a partir da pasta atual do app:
  /// no iPhone a pasta muda de nome quando o app é atualizado, então o
  /// caminho completo nunca é gravado.
  final String caminho;

  /// E-mail (oculto) que recebeu a cópia; nulo se não foi enviada.
  final String? emailMascarado;

  const CertidaoGuardada({
    required this.tipo,
    required this.titulo,
    required this.codigo,
    required this.geradoEm,
    required this.validoAte,
    required this.urlVerificacao,
    required this.nomeArquivo,
    required this.caminho,
    this.emailMascarado,
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
        'email_mascarado': emailMascarado,
      };

  factory CertidaoGuardada.fromJson(Map<String, dynamic> j, String pasta) =>
      CertidaoGuardada(
        tipo: j['tipo'].toString(),
        titulo: j['titulo'].toString(),
        codigo: j['codigo'].toString(),
        geradoEm: DateTime.parse(j['gerado_em'].toString()),
        validoAte: DateTime.parse(j['valido_ate'].toString()),
        urlVerificacao: j['url_verificacao'].toString(),
        nomeArquivo: j['nome_arquivo'].toString(),
        caminho: '$pasta/${j['codigo']}.pdf',
        emailMascarado: j['email_mascarado']?.toString(),
      );
}

/// Cópia por e-mail feita pela API logo depois da emissão.
class EnvioEmailCertidao {
  final bool enviado;

  /// E-mail com o meio oculto ("l***s@gmail.com"); nulo se não há confirmado.
  final String? emailMascarado;

  /// Explicação quando não foi enviado.
  final String? aviso;

  const EnvioEmailCertidao(
      {required this.enviado, this.emailMascarado, this.aviso});

  factory EnvioEmailCertidao.fromJson(Map<String, dynamic>? j) =>
      EnvioEmailCertidao(
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
  // Ler, gravar e limpar a lista nunca acontecem ao mesmo tempo: com duas
  // operações cruzadas, a limpeza da pasta via uma lista desatualizada e
  // apagava PDFs válidos.
  static Future<void> _fila = Future<void>.value();

  static Future<T> _emFila<T>(Future<T> Function() operacao) async {
    final anterior = _fila;
    final vez = Completer<void>();
    _fila = vez.future;
    try {
      await anterior;
      return await operacao();
    } finally {
      vez.complete();
    }
  }

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
    final semFracao =
        iso.contains('.') ? iso.substring(0, iso.indexOf('.')) : iso;
    return DateTime.parse('$semFracao-04:00').toLocal();
  }

  // ── Painel ────────────────────────────────────────────────────────────────

  static Future<PainelCertidoes> painel({
    required String matricula,
    required String senhaMd5,
  }) async {
    final r = await _requisitar({
      'acao': 'painel',
      'matricula': matricula,
      'senha': senhaMd5,
    }, emissao: false);
    if (r['code'] != 1) {
      throw CertidaoErro(
          (r['message'] ?? 'Não foi possível carregar.').toString());
    }
    try {
      final declaracao = (r['declaracao'] as Map).cast<String, dynamic>();
      return PainelCertidoes(
        tipos: (r['tipos'] as List)
            .map((t) =>
                TipoCertidao.fromJson((t as Map).cast<String, dynamic>()))
            .toList(),
        declaracaoVersao: (declaracao['versao'] as num).toInt(),
        declaracaoTexto: declaracao['texto'].toString(),
        validadeDias: (r['validade_dias'] as num?)?.toInt() ?? 30,
        revogadas: {
          for (final h in (r['historico'] as List? ?? const []))
            if ((h as Map)['revogada'] == true)
              h['codigo'].toString(): h['motivo']?.toString(),
        },
      );
    } catch (e) {
      debugPrint('[CERTIDAO] painel incompleto: $e');
      throw const CertidaoErro(
          'O servidor respondeu de forma inesperada. Tente de novo em alguns minutos.');
    }
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
    final r = await _requisitar({
      'acao': 'emitir',
      'matricula': matricula,
      'senha': senhaMd5,
      'tipo': tipo,
      'declaracao_confirmada': '1',
      'declaracao_versao': '$declaracaoVersao',
    }, emissao: true);

    if (r['code'] != 1) {
      throw CertidaoErro(
          (r['message'] ?? 'Não foi possível emitir.').toString());
    }

    final envio = EnvioEmailCertidao.fromJson(
        (r['email'] as Map?)?.cast<String, dynamic>());
    // Nada é guardado antes de a resposta e o PDF passarem na conferência.
    final bytes = _conferirResposta(r, tipo, envio);

    final certidao = CertidaoGuardada(
      tipo: r['tipo'].toString(),
      titulo: r['titulo'].toString(),
      codigo: r['codigo'].toString(),
      geradoEm: _dataApi(r['gerado_em'].toString()),
      validoAte: _dataApi(r['valido_ate'].toString()),
      urlVerificacao: r['url_verificacao'].toString(),
      nomeArquivo: r['nome_arquivo'].toString(),
      caminho: '',
      emailMascarado: envio.enviado ? envio.emailMascarado : null,
    );

    final Future<CertidaoGuardada> gravar = _emFila(() async {
      final lista = await _lerGuardadas(matricula);
      final arquivo =
          File('${(await _pasta(matricula)).path}/${certidao.codigo}.pdf');
      await arquivo.writeAsBytes(bytes, flush: true);
      final nova = CertidaoGuardada.fromJson(
          certidao.toJson(), (await _pasta(matricula)).path);
      await _salvarIndice(
          matricula, [nova, ...lista.where((c) => c.tipo != nova.tipo)]);
      // A anterior do mesmo tipo sai do aparelho (no servidor, foi revogada).
      for (final c in lista.where((c) => c.tipo == nova.tipo)) {
        final f = File(c.caminho);
        if (await f.exists()) await f.delete();
      }
      return nova;
    });
    final CertidaoGuardada guardada;
    try {
      guardada = await gravar;
    } catch (e) {
      // Ex.: aparelho sem espaço. No servidor a certidão já existe.
      debugPrint('[CERTIDAO] falha ao salvar: $e');
      throw CertidaoErro('Não foi possível salvar a certidão no aparelho '
          '(verifique o espaço livre). ${envio.enviado ? 'A cópia enviada para ${envio.emailMascarado ?? 'o seu e-mail'} é válida.' : 'Libere espaço e emita de novo.'}');
    }
    return EmissaoCertidao(certidao: guardada, email: envio);
  }

  // ── Conferências ──────────────────────────────────────────────────────────

  /// POST ao autoemissao.php. Toda falha vira CertidaoErro com uma mensagem
  /// que diz ao militar o que aconteceu com a certidão. Na emissão, "sem
  /// internet" (nada foi enviado) é diferente de "a conexão caiu esperando a
  /// resposta" (o servidor pode ter emitido e mandado a cópia por e-mail).
  static Future<Map<String, dynamic>> _requisitar(
    Map<String, String> corpo, {
    required bool emissao,
  }) async {
    final http.Response resposta;
    try {
      resposta = await http
          .post(Uri.parse('${ApiServices.baseUrl}/certidoes/autoemissao.php'),
              body: corpo)
          .timeout(Duration(seconds: emissao ? 60 : 25));
    } on SocketException catch (e) {
      debugPrint('[CERTIDAO] sem conexão: $e');
      throw CertidaoErro(emissao
          ? 'Sem conexão com a internet. Nenhuma certidão foi emitida. '
              'Verifique sua conexão e tente de novo.'
          : 'Sem conexão com a internet. Suas certidões salvas continuam '
              'disponíveis abaixo.');
    } on TimeoutException {
      throw CertidaoErro(emissao
          ? _msgConexaoCaiu
          : 'O SIGRH demorou para responder. Tente de novo em instantes.');
    } catch (e) {
      debugPrint('[CERTIDAO] falha de rede: $e');
      throw CertidaoErro(emissao
          ? _msgConexaoCaiu
          : 'Não foi possível falar com o servidor agora. Tente de novo.');
    }

    final entregue = emissao ? 'Nenhuma certidão foi entregue. ' : '';
    if (resposta.statusCode != 200) {
      throw CertidaoErro('O servidor do SIGRH está com problemas '
          '(erro ${resposta.statusCode}). ${entregue}Tente de novo em alguns minutos.');
    }
    try {
      return (jsonDecode(resposta.body) as Map).cast<String, dynamic>();
    } catch (e) {
      debugPrint('[CERTIDAO] resposta inválida: $e');
      throw CertidaoErro('O servidor respondeu de forma inesperada. '
          '${entregue}Tente de novo em alguns minutos.');
    }
  }

  static const _msgConexaoCaiu =
      'A conexão caiu antes de a certidão chegar. Se ela tiver sido emitida, '
      'a cópia chega no seu e-mail em instantes. Confira o e-mail antes de '
      'emitir de novo, porque uma nova emissão substitui a anterior.';

  /// Confere a resposta da emissão antes de guardar qualquer coisa: campos
  /// completos, o tipo pedido e o PDF íntegro (bate com o hash que o
  /// servidor calculou). Devolve os bytes do PDF.
  static List<int> _conferirResposta(
      Map<String, dynamic> r, String tipoPedido, EnvioEmailCertidao envio) {
    final copia = envio.enviado
        ? 'A cópia enviada para ${envio.emailMascarado ?? 'o seu e-mail'} é válida.'
        : 'Tente emitir de novo.';
    CertidaoErro corrompida() => CertidaoErro(
        'A certidão chegou incompleta ao aparelho e foi descartada. $copia');

    final codigo = r['codigo']?.toString() ?? '';
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(codigo) ||
        r['tipo']?.toString() != tipoPedido ||
        r['gerado_em'] == null ||
        r['valido_ate'] == null) {
      throw corrompida();
    }
    try {
      _dataApi(r['gerado_em'].toString());
      _dataApi(r['valido_ate'].toString());
    } catch (_) {
      throw corrompida();
    }

    final List<int> bytes;
    try {
      bytes = base64Decode(r['pdf_base64']?.toString() ?? '');
    } catch (_) {
      throw corrompida();
    }
    final inicio =
        bytes.length >= 5 ? String.fromCharCodes(bytes.sublist(0, 5)) : '';
    final fim = bytes.length >= 1024
        ? String.fromCharCodes(bytes.sublist(bytes.length - 1024))
        : '';
    if (inicio != '%PDF-' || !fim.contains('%%EOF')) throw corrompida();

    final hashServidor = r['pdf_sha256']?.toString();
    if (hashServidor != null &&
        sha256.convert(bytes).toString() != hashServidor) {
      throw corrompida();
    }
    return bytes;
  }

  // ── Guardadas no aparelho ─────────────────────────────────────────────────

  /// Certidões ainda válidas, mais recentes primeiro. Remove as vencidas e
  /// as que perderam o arquivo.
  static Future<List<CertidaoGuardada>> guardadas(String matricula) =>
      _emFila(() => _lerGuardadas(matricula));

  static Future<List<CertidaoGuardada>> _lerGuardadas(String matricula) async {
    final indice = await Store.getMap(_chaveIndice(matricula));
    final itens = (indice['itens'] as List?) ?? const [];
    final pasta = (await _pasta(matricula)).path;

    final validas = <CertidaoGuardada>[];
    var mudou = false;
    for (final item in itens) {
      try {
        final c = CertidaoGuardada.fromJson(
            (item as Map).cast<String, dynamic>(), pasta);
        final arquivo = File(c.caminho);
        if (c.valida && await arquivo.exists()) {
          validas.add(c);
        } else {
          mudou = true;
          debugPrint('[CERTIDAO] saiu do aparelho: ${c.tipo} ${c.codigo} '
              '(${c.valida ? 'arquivo ausente' : 'vencida'})');
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
        debugPrint('[CERTIDAO] saiu do aparelho: ${c.tipo} ${c.codigo} '
            '(substituída por uma mais recente)');
        final arquivo = File(c.caminho);
        if (await arquivo.exists()) await arquivo.delete();
      }
    }

    if (mudou) await _salvarIndice(matricula, ultimas);

    return ultimas;
  }

  static Future<void> _salvarIndice(
          String matricula, List<CertidaoGuardada> lista) =>
      Store.saveMap(_chaveIndice(matricula), {
        'itens': lista.map((c) => c.toJson()).toList(),
      });

  /// Tira do aparelho as certidões que o servidor revogou e devolve quais
  /// foram, com o motivo, para a tela avisar o militar.
  static Future<List<({CertidaoGuardada certidao, String? motivo})>>
      sincronizar(String matricula, PainelCertidoes painel) =>
          _emFila(() async {
            final lista = await _lerGuardadas(matricula);
            final saem = lista
                .where((c) => painel.revogadas.containsKey(c.codigo))
                .toList();
            if (saem.isEmpty) return const [];
            for (final c in saem) {
              debugPrint(
                  '[CERTIDAO] saiu do aparelho: ${c.tipo} ${c.codigo} (revogada)');
              final f = File(c.caminho);
              if (await f.exists()) await f.delete();
            }
            await _salvarIndice(
                matricula, lista.where((c) => !saem.contains(c)).toList());
            return [
              for (final c in saem)
                (certidao: c, motivo: painel.revogadas[c.codigo])
            ];
          });

  /// Tira uma certidão do aparelho (lista e arquivo). No servidor ela
  /// continua registrada e válida para quem já a recebeu.
  static Future<List<CertidaoGuardada>> remover(
          String matricula, String codigo) =>
      _emFila(() async {
        final lista = await _lerGuardadas(matricula);
        final resto = <CertidaoGuardada>[];
        for (final c in lista) {
          if (c.codigo == codigo) {
            final arquivo = File(c.caminho);
            if (await arquivo.exists()) await arquivo.delete();
          } else {
            resto.add(c);
          }
        }
        await _salvarIndice(matricula, resto);
        return resto;
      });

  /// Apaga todas as certidões do aparelho (logout).
  static Future<void> apagarTudo() async {
    try {
      final base = await getApplicationSupportDirectory();
      final dir = Directory('${base.path}/certidoes');
      if (await dir.exists()) {
        for (final sub in dir.listSync().whereType<Directory>()) {
          await Store.remove(_chaveIndice(
              sub.uri.pathSegments.where((s) => s.isNotEmpty).last));
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
