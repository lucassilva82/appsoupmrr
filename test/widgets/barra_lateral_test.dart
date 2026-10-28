import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projetonovo/widgets/barra_lateral.dart';
import 'package:projetonovo/widgets/barra_navegacao.dart';

void main() {
  const itens = [
    ItemNavegacao(icone: Icons.home_outlined, iconeAtivo: Icons.home, rotulo: 'Início'),
    ItemNavegacao(icone: Icons.apps_outlined, iconeAtivo: Icons.apps, rotulo: 'Serviços'),
    ItemNavegacao(
        icone: Icons.notifications_outlined,
        iconeAtivo: Icons.notifications,
        rotulo: 'Avisos',
        contador: 12),
    ItemNavegacao(icone: Icons.person_outline, iconeAtivo: Icons.person, rotulo: 'Perfil'),
  ];

  testWidgets('iPad: as quatro abas na lateral, com contador e troca', (t) async {
    t.view.physicalSize = const Size(1180, 820);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    int? escolhida;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Row(children: [
          BarraLateral(
              itens: itens,
              indice: 0,
              aoSelecionar: (i) => escolhida = i,
              estendida: true),
          const Expanded(child: SizedBox()),
        ]),
      ),
    ));
    for (final r in ['Início', 'Serviços', 'Avisos', 'Perfil']) {
      expect(find.text(r), findsOneWidget);
    }
    expect(find.text('9+'), findsOneWidget);
    await t.tap(find.text('Serviços'));
    expect(escolhida, 1);
    expect(t.takeException(), isNull);
  });
}
