import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:projetonovo/vitrine/vitrine.dart';

void main() {
  test('vitrine: feedback lê campo com acento e com quebra de linha', () async {
    final pedido = http.MultipartRequest('POST', Uri.parse('https://pmrr.online/flutter/sigrh/feedback.php'))
      ..fields.addAll({'acao': 'enviar', 'tipo': 'elogio', 'texto': 'Do mês inteiro\nobrigado'});
    final corpo = await pedido.finalize().toBytes();
    final r = await clienteVitrine().send(http.Request('POST', pedido.url)
      ..headers.addAll(pedido.headers)
      ..bodyBytes = corpo);
    final j = jsonDecode(await r.stream.bytesToString()) as Map;
    expect(j['code'], 1);
    final lista = await clienteVitrine().send(http.Request('POST', pedido.url)
      ..bodyBytes = await (http.MultipartRequest('POST', pedido.url)..fields['acao'] = 'listar').finalize().toBytes());
    final itens = (jsonDecode(await lista.stream.bytesToString()) as Map)['itens'] as List;
    expect(itens.first['trecho'], 'Do mês inteiro\nobrigado');
  });
}
