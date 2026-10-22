import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:projetonovo/core/erros/falha_app.dart';
import 'package:projetonovo/core/rede/api_client.dart';

void main() {
  final url = Uri.parse('https://exemplo.invalid/sigrh/teste.php');

  ApiClient cliente(MockClientHandler h, {bool temInternet = true}) =>
      ApiClient(
        cliente: MockClient(h),
        tempoLimite: const Duration(milliseconds: 200),
        temInternet: () async => temInternet,
      );

  Future<FalhaApp> falhaDe(Future<Object?> Function() f) async {
    try {
      await f();
    } on FalhaApp catch (e) {
      return e;
    }
    fail('devia lançar FalhaApp');
  }

  test('resposta JSON 200 volta decodificada', () async {
    final api = cliente((_) async => http.Response.bytes(
        utf8.encode(jsonEncode({'code': 1, 'nome': 'José'})), 200));
    final r = await api.postJson(url, prefixo: 'CC', campos: {'a': '1'});
    expect(r, {'code': 1, 'nome': 'José'});
  });

  test('manda a versão e a plataforma do app em todo pedido', () async {
    late http.BaseRequest pedido;
    final api = cliente((req) async {
      pedido = req;
      return http.Response('{}', 200);
    });
    await api.getJson(url, prefixo: 'CC');
    expect(pedido.headers['X-App-Versao'], isNotEmpty);
    expect(pedido.headers['X-App-Plataforma'], isNotEmpty);
  });

  test('HTTP 503 vira <prefixo>-SRV-503, problema do servidor', () async {
    final api = cliente((_) async => http.Response('fora', 503));
    final f = await falhaDe(() => api.getJson(url, prefixo: 'CC'));
    expect(f.codigo, 'CC-SRV-503');
    expect(f.origem, OrigemFalha.servidor);
  });

  test('resposta que não é JSON vira <prefixo>-RESP', () async {
    final api = cliente((_) async => http.Response('<html>portal</html>', 200));
    final f = await falhaDe(() => api.getJson(url, prefixo: 'FE'));
    expect(f.codigo, 'FE-RESP');
  });

  test('demora além do tempo limite vira <prefixo>-LENTO', () async {
    final api = cliente((_) async {
      await Future<void>.delayed(const Duration(seconds: 1));
      return http.Response('{}', 200);
    });
    final f = await falhaDe(() => api.getJson(url, prefixo: 'CT'));
    expect(f.codigo, 'CT-LENTO');
    expect(f.origem, OrigemFalha.servidor);
  });

  test('sem internet no aparelho vira <prefixo>-REDE', () async {
    final api = cliente((_) async => throw const SocketException('sem rede'),
        temInternet: false);
    final f = await falhaDe(() => api.getJson(url, prefixo: 'CC'));
    expect(f.codigo, 'CC-REDE');
    expect(f.origem, OrigemFalha.rede);
  });

  test('com internet, mas o servidor não atende, vira <prefixo>-FORA',
      () async {
    final api = cliente((_) async => throw const SocketException('recusado'));
    final f = await falhaDe(() => api.getJson(url, prefixo: 'CC'));
    expect(f.codigo, 'CC-FORA');
    expect(f.origem, OrigemFalha.servidor);
  });

  test('conexão segura recusada vira <prefixo>-SSL', () async {
    final api = cliente((_) async => throw const HandshakeException('cert'));
    final f = await falhaDe(() => api.getJson(url, prefixo: 'CC'));
    expect(f.codigo, 'CC-SSL');
    expect(f.origem, OrigemFalha.aparelho);
  });

  test('toda falha tem título e texto para a tela, nunca vazios', () async {
    final api = cliente((_) async => http.Response('x', 500));
    final f = await falhaDe(() => api.getJson(url, prefixo: 'CC'));
    expect(f.titulo, isNotEmpty);
    expect(f.texto, isNotEmpty);
    expect(f.texto.toLowerCase(), isNot(contains('ocorreu um erro')));
  });
}
