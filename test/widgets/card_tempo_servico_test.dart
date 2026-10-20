// O card de tempo de serviço somava o tempo averbado (IPER) e, quando a
// consulta falhava, zerava o averbado em silêncio e dizia "sem tempo agregado
// do IPER", como se o militar não tivesse tempo averbado (caso do SD Sousa
// Rios, 20/10/2026). Estes testes travam a diferença entre "não tem" e "não
// consegui consultar".
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:projetonovo/models/auth_model.dart';
import 'package:projetonovo/widgets/card_tempo_servico.dart';
import 'package:provider/provider.dart';

Widget _montar(http.Client cliente) {
  final auth = Auth()
    ..matricula = '456012'
    ..dataIncorporacao = '2020-01-01';
  return ChangeNotifierProvider<Auth>.value(
    value: auth,
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: CardTempoServico(cliente: cliente)),
      ),
    ),
  );
}

http.Response _json(Object corpo) =>
    http.Response(jsonEncode(corpo), 200, headers: {'content-type': 'application/json'});

void main() {
  testWidgets('averbado encontrado aparece no rodapé', (tester) async {
    final cliente = MockClient((_) async => _json({
          'code': 1,
          'result': [
            {'poip_total_dias': 5993, 'poip_matricula': 456012}
          ]
        }));
    await tester.pumpWidget(_montar(cliente));
    await tester.pumpAndSettle();
    expect(find.textContaining('IPER: 16 anos, 5 meses e 3 dias'), findsOneWidget);
  });

  testWidgets('sem registro no IPER diz que não há tempo agregado', (tester) async {
    final cliente = MockClient((_) async => _json({
          'code': 0,
          'message': 'Nenhum dado encontrado para a matrícula informada.'
        }));
    await tester.pumpWidget(_montar(cliente));
    await tester.pumpAndSettle();
    expect(find.textContaining('sem tempo agregado do IPER'), findsOneWidget);
  });

  testWidgets('falha de rede não pode virar "sem tempo agregado"', (tester) async {
    final cliente = MockClient((_) async => throw http.ClientException('sem rede'));
    await tester.pumpWidget(_montar(cliente));
    await tester.pumpAndSettle();
    expect(find.textContaining('sem tempo agregado'), findsNothing);
    expect(find.textContaining('Averbado indisponível'), findsOneWidget);
    expect(find.textContaining('TS-IPER-REDE'), findsOneWidget);
    expect(find.byTooltip('Tentar de novo'), findsOneWidget);
  });

  testWidgets('erro do banco na API também é avisado', (tester) async {
    final cliente = MockClient((_) async => _json({
          'code': 0,
          'message': 'Erro ao consultar o banco de dados.'
        }));
    await tester.pumpWidget(_montar(cliente));
    await tester.pumpAndSettle();
    expect(find.textContaining('sem tempo agregado'), findsNothing);
    expect(find.textContaining('TS-IPER-API'), findsOneWidget);
  });

  testWidgets('Tentar de novo refaz a consulta e mostra o averbado', (tester) async {
    var chamadas = 0;
    final cliente = MockClient((_) async {
      chamadas++;
      if (chamadas == 1) throw http.ClientException('sem rede');
      return _json({
        'code': 1,
        'result': [
          {'poip_total_dias': 5993}
        ]
      });
    });
    await tester.pumpWidget(_montar(cliente));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tentar de novo'));
    await tester.pumpAndSettle();
    expect(chamadas, 2);
    expect(find.textContaining('IPER: 16 anos, 5 meses e 3 dias'), findsOneWidget);
  });
}
