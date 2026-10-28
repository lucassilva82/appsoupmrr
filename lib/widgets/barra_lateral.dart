import 'package:flutter/material.dart';

import 'barra_navegacao.dart';
import 'barra_vidro.dart';

/// As abas na lateral, para iPad e Android largo (docs/SOUPM_2_2.md §3.1 e
/// §15.4). Compacta entre 600 e 840 pt; a partir de 840, com o nome.
class BarraLateral extends StatelessWidget {
  const BarraLateral({
    super.key,
    required this.itens,
    required this.indice,
    required this.aoSelecionar,
    required this.estendida,
  });

  final List<ItemNavegacao> itens;
  final int indice;
  final ValueChanged<int> aoSelecionar;
  final bool estendida;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(children: [
      const Positioned.fill(child: FundoBarraVidro()),
      NavigationRail(
        backgroundColor: Colors.transparent,
        extended: estendida,
        minExtendedWidth: 220,
        selectedIndex: indice,
        onDestinationSelected: aoSelecionar,
        labelType: estendida ? NavigationRailLabelType.none : NavigationRailLabelType.all,
        indicatorColor: Colors.white.withValues(alpha: 0.16),
        selectedIconTheme: const IconThemeData(color: Colors.white),
        unselectedIconTheme:
            IconThemeData(color: Colors.white.withValues(alpha: 0.7)),
        selectedLabelTextStyle: theme.textTheme.labelLarge
            ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
        unselectedLabelTextStyle: theme.textTheme.labelLarge
            ?.copyWith(color: Colors.white.withValues(alpha: 0.75)),
        destinations: [
          for (final i in itens)
            NavigationRailDestination(
              icon: Badge(
                isLabelVisible: i.contador > 0,
                label: Text(i.contador > 9 ? '9+' : '${i.contador}'),
                child: Icon(i.icone),
              ),
              selectedIcon: Icon(i.iconeAtivo),
              label: Text(i.rotulo),
            ),
        ],
      ),
    ]);
  }
}

