import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:projetonovo/core/erros/falha_app.dart';
import 'package:projetonovo/core/rede/api_client.dart';
import 'package:projetonovo/features/contracheque/contracheque_pdf_repositorio.dart';
import 'package:projetonovo/models/meses_contracheque_model.dart';

final _mes = MesesContracheque(
    tipo: 'B', codProvento: '', mes: '9', folha: 'FOLHA NORMAL', mesExtenso: 'Setembro',
    relacaoTrabalho: 'MILITAR', cpf: '00000000000', ano: '2026', matricula: '1234567-0-01');

ContrachequePdfRepositorio _repo(Object resposta, {void Function(http.Request)? viu}) => ContrachequePdfRepositorio(
      api: ApiClient(
          cliente: MockClient((r) async {
            viu?.call(r);
            return http.Response(jsonEncode(resposta), 200,
                headers: {'content-type': 'application/json; charset=utf-8'});
          }),
          temInternet: () async => true),
      matricula: '1234567',
      senhaMd5: 'a' * 32,
      url: Uri.parse('https://teste/contracheque_pdf.php'),
    );

void main() {
  late Directory pasta;
  setUp(() => pasta = Directory.systemTemp.createTempSync('cc_pdf'));
  tearDown(() => pasta.deleteSync(recursive: true));

  final pdf = utf8.encode('%PDF-1.7 contracheque fictício %%EOF');

  test('guarda o PDF quando o SHA-256 confere, sem mandar o CPF do app', () async {
    late http.Request pedido;
    final f = await _repo({
      'code': 1, 'pdf_base64': base64Encode(pdf), 'sha256': sha256.convert(pdf).toString(),
      'nome_arquivo': 'Contracheque 2026-09.pdf', 'versao_padrao': 0,
    }, viu: (r) => pedido = r).pedir(_mes, pasta: pasta);
    expect(await f!.readAsBytes(), pdf);
    expect(f.path, endsWith('Contracheque 2026-09.pdf'));
    expect(pedido.bodyFields['vinculo'], '1234567-0-01');
    expect(pedido.bodyFields.containsKey('cpf'), isFalse, reason: 'o CPF sai do servidor');
  });

  test('SHA-256 diferente: CC-HASH e nada guardado', () async {
    await expectLater(
      _repo({'code': 1, 'pdf_base64': base64Encode(pdf), 'sha256': 'f' * 64}).pedir(_mes, pasta: pasta),
      throwsA(isA<FalhaApp>().having((f) => f.codigo, 'codigo', 'CC-HASH')),
    );
    expect(pasta.listSync(), isEmpty);
  });

  test('DESLIGADO no painel: devolve nulo (a tela usa o PDF de hoje)', () async {
    expect(await _repo({'code': 0, 'erro': 'DESLIGADO', 'message': '...'}).pedir(_mes, pasta: pasta), isNull);
  });

  test('mês sem folha vira CC-SEM-FOLHA com o texto do servidor', () async {
    await expectLater(
      _repo({'code': 0, 'erro': 'SEM_FOLHA', 'message': 'Não há folha publicada.'}).pedir(_mes, pasta: pasta),
      throwsA(isA<FalhaApp>()
          .having((f) => f.codigo, 'codigo', 'CC-SEM-FOLHA')
          .having((f) => f.texto, 'texto', 'Não há folha publicada.')),
    );
  });
}
