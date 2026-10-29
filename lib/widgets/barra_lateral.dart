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
    final escuro = theme.brightness == Brightness.dark;
    // As cores vêm do tema, como na barra de baixo (`BarraNavegacao`): ativo na
    // primária, o resto em onSurface. Branco fixo sumia no tema claro, porque o
    // FundoBarraVidro é quase branco ali — a lateral aparecia como uma faixa
    // vazia no tablet (relatado em 29/10/2026). É o DESIGN §6: cor clara não
    // vira texto.
    final ativo = theme.colorScheme.primary;
    // 62% é o mínimo que fecha 4,5:1 no tema claro (DESIGN §6); no escuro 70%
    // já passa com folga.
    final apagado = theme.colorScheme.onSurface.withValues(alpha: escuro ? 0.70 : 0.68);
    return Stack(children: [
      const Positioned.fill(child: FundoBarraVidro()),
      NavigationRail(
        backgroundColor: Colors.transparent,
        extended: estendida,
        minExtendedWidth: 220,
        selectedIndex: indice,
        onDestinationSelected: aoSelecionar,
        labelType: estendida ? NavigationRailLabelType.none : NavigationRailLabelType.all,
        indicatorColor: ativo.withValues(alpha: escuro ? 0.18 : 0.12),
        selectedIconTheme: IconThemeData(color: ativo),
        unselectedIconTheme: IconThemeData(color: apagado),
        selectedLabelTextStyle: theme.textTheme.labelLarge
            ?.copyWith(color: ativo, fontWeight: FontWeight.w700),
        unselectedLabelTextStyle: theme.textTheme.labelLarge
            ?.copyWith(color: apagado),
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

