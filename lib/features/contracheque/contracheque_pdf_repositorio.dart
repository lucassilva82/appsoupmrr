import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../core/ambiente_app.dart';
import '../../core/enderecos.dart';
import '../../core/erros/falha_app.dart';
import '../../core/log/registro_log.dart';
import '../../core/rede/api_client.dart';
import '../../models/meses_contracheque_model.dart';

/// O PDF do contracheque montado na API (docs/SOUPM_2_2.md §12.3): o app
/// pede, confere o SHA-256 e guarda. Nada de documento oficial montado no
/// aparelho.
///
/// Transição: enquanto o painel não liga `contracheque.pdf_api` (depois da
/// comparação página por página com o PDF de hoje), a API responde
/// DESLIGADO e [pedir] devolve nulo: a tela usa o PDF montado no aparelho.
class ContrachequePdfRepositorio {
  ContrachequePdfRepositorio({required this.api, required this.matricula, required this.senhaMd5, Uri? url})
      : url = url ?? Uri.parse('$urlSigrh/contracheque_pdf.php');

  final ApiClient api;
  final String matricula;
  final String senhaMd5;
  final Uri url;

  static const prefixo = 'CC';

  /// Grava em [pasta] e devolve o arquivo; nulo = a API ainda não emite.
  Future<File?> pedir(MesesContracheque mes, {required Directory pasta}) async {
    final inicio = DateTime.now();
    final j = await api.postJson(url, prefixo: prefixo, campos: {
      'matricula': matricula,
      'senha': senhaMd5,
      'plataforma': AmbienteApp.plataforma,
      'app_versao': AmbienteApp.versao,
      'tipo': mes.tipo,
      'ano': mes.ano,
      'mes': mes.mes,
      'vinculo': mes.matricula,
      'folha': mes.folha,
      'relacao': mes.relacaoTrabalho,
      'cod': mes.codProvento,
    });
    if (j is! Map) throw FalhaApp.respostaInvalida(prefixo, detalhe: 'contracheque_pdf.php não devolveu objeto');
    if (j['code'] != 1) {
      final erro = '${j['erro'] ?? 'ERRO_SERVIDOR'}';
      if (erro == 'DESLIGADO') return null;
      registrar('contracheque.pdf_pedir', chave: 'rh.contracheques', resultado: 'falhou', codigo: 'CC-${erro.replaceAll('_', '-')}');
      throw FalhaApp.daApi(prefixo, erro, j['message'] as String?);
    }
    final List<int> bytes;
    try {
      bytes = base64Decode('${j['pdf_base64']}');
    } catch (_) {
      throw FalhaApp.respostaInvalida(prefixo, detalhe: 'pdf_base64 inválido');
    }
    final bateu = sha256.convert(bytes).toString() == j['sha256'];
    registrar('contracheque.pdf_conferir', chave: 'rh.contracheques', resultado: bateu ? 'ok' : 'falhou',
        codigo: bateu ? null : 'CC-HASH');
    if (!bateu) {
      throw const FalhaApp(
          codigo: 'CC-HASH',
          origem: OrigemFalha.rede,
          titulo: 'O PDF chegou incompleto',
          texto: 'O arquivo não confere com o que o servidor gerou, por isso não foi guardado. Tente de novo.',
          detalhe: 'SHA-256 diferente');
    }
    registrar('contracheque.pdf_pedir', chave: 'rh.contracheques',
        dados: {'ms': DateTime.now().difference(inicio).inMilliseconds, 'versao_padrao': j['versao_padrao']});
    final nome = '${j['nome_arquivo'] ?? 'Contracheque.pdf'}'.replaceAll(RegExp(r'[^\w .-]'), '_');
    final arquivo = File('${pasta.path}/$nome');
    try {
      await arquivo.writeAsBytes(bytes, flush: true);
    } on FileSystemException catch (e) {
      throw FalhaApp(
          codigo: 'CC-GRAVAR',
          origem: OrigemFalha.aparelho,
          titulo: 'Não foi possível guardar o PDF',
          texto: 'O aparelho não deixou gravar o arquivo. Libere espaço e tente de novo.',
          detalhe: '$e');
    }
    return arquivo;
  }
}
