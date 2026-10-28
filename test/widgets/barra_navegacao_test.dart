import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projetonovo/widgets/barra_navegacao.dart';

void main() {
  const itens = [
    ItemNavegacao(icone: Icons.home_outlined, iconeAtivo: Icons.home_rounded, rotulo: 'Início'),
    ItemNavegacao(icone: Icons.apps_outlined, iconeAtivo: Icons.apps_rounded, rotulo: 'Serviços'),
    ItemNavegacao(icone: Icons.notifications_outlined, iconeAtivo: Icons.notifications_rounded, rotulo: 'Avisos', contador: 3),
    ItemNavegacao(icone: Icons.person_outline, iconeAtivo: Icons.person_rounded, rotulo: 'Perfil'),
  ];

  Future<List<int>> tocarTodas(WidgetTester t, {required bool ios}) async {
    final tocadas = <int>[];
    var atual = 0;
    await t.pumpWidget(MaterialApp(
      home: StatefulBuilder(
        builder: (context, set) => Scaffold(
          bottomNavigationBar: BarraNavegacao(
            ios: ios,
            itens: itens,
            indiceAtual: atual,
            aoSelecionar: (i) => set(() {
              tocadas.add(i);
              atual = i;
            }),
          ),
        ),
      ),
    ));
    for (final rotulo in ['Serviços', 'Avisos, 3 não lidos', 'Perfil', 'Início']) {
      await t.tap(find.bySemanticsLabel(rotulo));
      await t.pumpAndSettle();
    }
    return tocadas;
  }

  testWidgets('iOS: um toque em cada aba troca na hora', (t) async {
    expect(await tocarTodas(t, ios: true), [1, 2, 3, 0]);
  });

  testWidgets('Android: um toque em cada aba troca na hora', (t) async {
    expect(await tocarTodas(t, ios: false), [1, 2, 3, 0]);
  });
}
