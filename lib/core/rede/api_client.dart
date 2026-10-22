import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../ambiente_app.dart';
import '../erros/falha_app.dart';

/// Cliente HTTP único do app (docs/SOUPM_2_2.md §9.1).
///
/// Toda chamada à API passa por aqui, e toda falha sai como [FalhaApp] com o
/// prefixo do módulo, nunca como exceção crua. Também manda versão e
/// plataforma do app em todo pedido, para o servidor e o painel saberem quem
/// está em cada versão.
///
/// No modo vitrine o `main` roda o app dentro de `http.runWithClient`, e o
/// `http.Client()` criado aqui já é o cliente fictício: nada muda neste arquivo.
class ApiClient {
  ApiClient({
    http.Client? cliente,
    this.tempoLimite = const Duration(seconds: 15),
    Future<bool> Function()? temInternet,
  })  : _cliente = cliente,
        _temInternet = temInternet ?? _internetPorDns;

  final http.Client? _cliente;

  /// Padrão do §9.1; o `app_config` (`rede.timeout_s`) pode trocar.
  Duration tempoLimite;
  final Future<bool> Function() _temInternet;

  // Criado uma vez, já dentro da zona do `main` (modo vitrine incluído).
  late final http.Client _c = _cliente ?? http.Client();

  Map<String, String> get _cabecalhos => {
        'X-App-Versao': AmbienteApp.versao,
        'X-App-Build': AmbienteApp.build,
        'X-App-Plataforma': AmbienteApp.plataforma,
      };

  /// GET que espera JSON. [prefixo] é o do módulo (`CC`, `CT`…).
  Future<dynamic> getJson(Uri url, {required String prefixo}) =>
      _enviar(prefixo, () => _c.get(url, headers: _cabecalhos));

  /// POST de formulário que espera JSON. Dado do militar vai sempre no corpo,
  /// nunca na URL (§12.1).
  Future<dynamic> postJson(
    Uri url, {
    required String prefixo,
    Map<String, String>? campos,
  }) =>
      _enviar(prefixo, () => _c.post(url, headers: _cabecalhos, body: campos));

  /// POST com corpo JSON (lotes do log, por exemplo).
  Future<dynamic> postCorpoJson(
    Uri url, {
    required String prefixo,
    required Object corpo,
  }) =>
      _enviar(
          prefixo,
          () => _c.post(url,
              headers: {
                ..._cabecalhos,
                'Content-Type': 'application/json; charset=utf-8',
              },
              body: jsonEncode(corpo)));

  /// POST com corpo JSON que aproveita a cópia guardada: manda o último
  /// [etag] em `If-None-Match` e, se o servidor responder 304, devolve
  /// [RespostaComEtag.naoMudou] sem corpo (o `app_config`, §5.3).
  Future<RespostaComEtag> postCorpoJsonComEtag(
    Uri url, {
    required String prefixo,
    required Object corpo,
    String? etag,
  }) async {
    final resposta = await _pedir(
        prefixo,
        () => _c.post(url,
            headers: {
              ..._cabecalhos,
              'Content-Type': 'application/json; charset=utf-8',
              if (etag != null) 'If-None-Match': etag,
            },
            body: jsonEncode(corpo)),
        aceita304: true);
    if (resposta.statusCode == 304) {
      return RespostaComEtag(naoMudou: true, etag: etag);
    }
    return RespostaComEtag(
        json: _decodificar(prefixo, resposta), etag: resposta.headers['etag']);
  }

  Future<dynamic> _enviar(
          String prefixo, Future<http.Response> Function() pedido) async =>
      _decodificar(prefixo, await _pedir(prefixo, pedido));

  Future<http.Response> _pedir(
      String prefixo, Future<http.Response> Function() pedido,
      {bool aceita304 = false}) async {
    final http.Response resposta;
    try {
      resposta = await pedido().timeout(tempoLimite);
    } on TimeoutException catch (e) {
      throw FalhaApp.lento(prefixo, detalhe: '$e');
    } on HandshakeException catch (e) {
      throw FalhaApp.conexaoSegura(prefixo, detalhe: '$e');
    } on SocketException catch (e) {
      throw await _semConexao(prefixo, e);
    } on http.ClientException catch (e) {
      throw await _semConexao(prefixo, e);
    }

    if (resposta.statusCode != 200 &&
        !(aceita304 && resposta.statusCode == 304)) {
      throw FalhaApp.httpStatus(prefixo, resposta.statusCode,
          detalhe: 'HTTP ${resposta.statusCode}');
    }
    return resposta;
  }

  dynamic _decodificar(String prefixo, http.Response resposta) {
    try {
      return jsonDecode(utf8.decode(resposta.bodyBytes));
    } catch (e) {
      throw FalhaApp.respostaInvalida(prefixo, detalhe: 'não é JSON: $e');
    }
  }

  /// Distingue "aparelho sem internet" de "nosso servidor fora do ar".
  Future<FalhaApp> _semConexao(String prefixo, Object e) async =>
      await _temInternet()
          ? FalhaApp.servidorFora(prefixo, detalhe: '$e')
          : FalhaApp.semInternet(prefixo, detalhe: '$e');

  // Só para testar "sem internet" no simulador, que usa a rede do Mac.
  static const _hostTeste =
      String.fromEnvironment('HOST_TESTE_INTERNET', defaultValue: 'google.com');

  static Future<bool> _internetPorDns() async {
    try {
      final r = await InternetAddress.lookup(_hostTeste)
          .timeout(const Duration(seconds: 4));
      return r.isNotEmpty && r.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}

/// Resultado de [ApiClient.postCorpoJsonComEtag].
class RespostaComEtag {
  const RespostaComEtag({this.naoMudou = false, this.json, this.etag});

  /// O servidor respondeu 304: vale a cópia guardada.
  final bool naoMudou;
  final dynamic json;
  final String? etag;
}
